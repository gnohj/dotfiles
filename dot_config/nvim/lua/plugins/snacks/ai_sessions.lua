-- Unified Snacks picker over a coding agent's past sessions - Claude Code, Pi,
-- and opencode - read straight from each agent's on-disk history so it works
-- whether or not that agent's terminal is running. Fuzzy-matches on a derived
-- label, previews the recent exchange, and resumes the pick.
--
-- Loading is async: the picker opens instantly and streams rows in through
-- Snacks' `proc` finder (which shows a native loading spinner) as a single
-- batched shell pass derives each session's label. One subprocess, not one per
-- session, so a project with dozens of transcripts still fills in quickly.
--
-- Resume has two modes, chosen by the AI_PICK_FILE env var:
--   * Handoff (AI_PICK_FILE set): the picker was launched by a terminal wrapper
--     (cr / pir / ocr) that opened nvim solely to pick. Write the chosen id to
--     that file and quit nvim; the wrapper then execs the agent in the SAME
--     pane. This is the "resume in place" terminal flow.
--   * Split (no AI_PICK_FILE): the picker was opened inside a working nvim
--     (<leader> maps / dashboard). Resume in a side split via config.mux so it
--     never destroys the editor or dashboard pane.
--
-- Per-agent storage (all keyed to the current working directory):
--   Claude    ~/.claude/projects/<cwd with / and . -> ->/<uuid>.jsonl
--   Pi        ~/.pi/agent/sessions/--<cwd sans leading /, / -> ->--/<ts>_<uuid>.jsonl
--   opencode  ~/.local/share/opencode/storage/session/global/ses_*.json
--             (all projects in one dir; filtered by the session's .directory)

local M = {}

local function age(mtime)
  local s = os.time() - mtime
  if s < 3600 then
    return math.max(1, math.floor(s / 60)) .. "m ago"
  elseif s < 86400 then
    return math.floor(s / 3600) .. "h ago"
  end
  return math.floor(s / 86400) .. "d ago"
end

-- Each batch pass emits one "id \t mtime \t file \t label" line per session.
-- Parse it into a picker item; match on the label rather than the raw line.
local function transform(item)
  local id, mtime, file, title = item.text:match("^(.-)\t(.-)\t(.-)\t(.*)$")
  if not id then
    return false
  end
  item.id = id
  item.mtime = tonumber(mtime) or 0
  item.file = file
  item.title = title
  item.text = title
  return item
end

-- spec: { title, icon, cmd, args, preview_cmd, resume(id) }
local function pick(spec)
  Snacks.picker.pick({
    title = spec.title,
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc(
        ctx:opts({
          cmd = spec.cmd,
          args = spec.args,
          notify = false,
          transform = transform,
        }),
        ctx
      )
    end,
    format = function(item)
      return {
        { spec.icon, virtual = true },
        { item.title or "", "SnacksPickerLabel" },
        { " " .. age(item.mtime or 0), "SnacksPickerComment" },
      }
    end,
    preview = function(ctx)
      -- Parse each transcript once, then cache; large sessions make the shell
      -- pass too slow to re-run on every list movement.
      if not ctx.item.preview_lines then
        if spec.preview_cmd and ctx.item.file and ctx.item.file ~= "" then
          ctx.item.preview_lines =
            vim.fn.systemlist({ "bash", "-c", spec.preview_cmd, "preview", ctx.item.file })
        else
          ctx.item.preview_lines = { ctx.item.title or "" }
        end
      end
      ctx.preview:set_lines(ctx.item.preview_lines)
      ctx.preview:set_title(ctx.item.title or spec.title)
      return true
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      local handoff = vim.env.AI_PICK_FILE
      if handoff and handoff ~= "" then
        vim.fn.writefile({ item.id }, handoff)
        vim.cmd("qa!")
      else
        require("config.mux").agent_split(spec.resume(item.id))
      end
    end,
  })
end

-- Shared tail of a jsonl batch pass: newest-first, emit id/mtime/file/label.
-- $1 is the sessions dir; `session_id "<file>"` and `session_label "<file>"`
-- must be defined above it.
local jsonl_batch_tail = [==[
dir="$1"
for f in $(ls -t "$dir"/*.jsonl 2>/dev/null); do
  [ -f "$f" ] || continue
  id="$(session_id "$f")"
  mt="$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null)"
  lbl="$(session_label "$f" | tr '\t\n' '  ')"
  [ -z "$lbl" ] && lbl="Untitled (${id:0:8})"
  printf '%s\t%s\t%s\t%s\n' "$id" "$mt" "$f" "$lbl"
done
]==]

-- ---- Claude Code -----------------------------------------------------------

local claude_label = require("plugins.snacks.claude_label")

local claude_batch = claude_label .. [==[
session_id() { basename "$1" .jsonl; }
session_label() { claude_label "$1"; }
]==] .. jsonl_batch_tail

local claude_preview = [[
jq -r 'select(.type == "user" or .type == "assistant")
  | (.message.content | if type == "string" then . else (map(select(.type == "text").text) | join("\n")) end) as $t
  | select($t != null and $t != "")
  | "-- \(.type) --\n\($t)\n"' "$1" 2>/dev/null | tail -120
]]

function M.claude()
  local dir = vim.fs.joinpath(vim.fn.expand("~/.claude/projects"), (vim.fn.getcwd():gsub("[/.]", "-")))
  pick({
    title = "Claude Conversations",
    icon = "💬 ",
    cmd = "bash",
    args = { "-c", claude_batch, "claude", dir },
    preview_cmd = claude_preview,
    resume = function(id)
      return "cr " .. id
    end,
  })
end

-- ---- Pi --------------------------------------------------------------------

-- Pi has no AI-generated title, so the label is the first typed user prompt.
local pi_batch = [==[
session_id() { base="$(basename "$1" .jsonl)"; printf '%s' "${base##*_}"; }
session_label() {
  jq -r 'select(.type == "message" and .message.role == "user")
    | (.message.content | if type == "array" then (map(select(.type == "text").text) | join(" ")) else tostring end)' "$1" 2>/dev/null \
    | grep -v '^[[:space:]]*$' | head -1 | tr '\n' ' ' | cut -c1-80
}
]==] .. jsonl_batch_tail

local pi_preview = [[
jq -r 'select(.type == "message")
  | .message as $m
  | ($m.content | if type == "array" then (map(select(.type == "text").text) | join("\n")) else tostring end) as $t
  | select($t != null and $t != "")
  | "-- \($m.role) --\n\($t)\n"' "$1" 2>/dev/null | tail -120
]]

function M.pi()
  local enc = "--" .. vim.fn.getcwd():gsub("^/", ""):gsub("/", "-") .. "--"
  local dir = vim.fs.joinpath(vim.fn.expand("~/.pi/agent/sessions"), enc)
  pick({
    title = "Pi Sessions",
    icon = "π ",
    cmd = "bash",
    args = { "-c", pi_batch, "pi", dir },
    preview_cmd = pi_preview,
    resume = function(id)
      return "pir " .. id
    end,
  })
end

-- ---- opencode --------------------------------------------------------------

-- opencode stores every project's sessions in one global dir with a real title
-- and directory on each, so filter by cwd and skip child (sub-agent) sessions.
-- @tsv emits the same id/mtime/file/label columns as the jsonl agents (file is
-- the session id, which the preview pass expands into its message dir).
local opencode_batch = [==[
jq -sr --arg cwd "$1" '
  [.[] | select(.directory == $cwd and (has("parentID") | not))]
  | sort_by(.time.updated) | reverse | .[]
  | [.id, ((.time.updated / 1000) | floor | tostring), .id, (.title // "Untitled")] | @tsv
' "$2"/*.json 2>/dev/null
]==]

local opencode_preview = [[
sid="$1"
base="$HOME/.local/share/opencode/storage"
for md in $(ls -tr "$base/message/$sid"/msg_*.json 2>/dev/null); do
  mid=$(basename "$md" .json)
  role=$(jq -r '.role // "?"' "$md" 2>/dev/null)
  txt=$(cat "$base/part/$mid"/prt_*.json 2>/dev/null | jq -rs 'map(select(.type == "text").text) | join("\n")' 2>/dev/null)
  [ -n "$txt" ] && printf -- '-- %s --\n%s\n' "$role" "$txt"
done | tail -120
]]

function M.opencode()
  local dir = vim.fn.expand("~/.local/share/opencode/storage/session/global")
  pick({
    title = "Opencode Sessions",
    icon = " ",
    cmd = "bash",
    args = { "-c", opencode_batch, "oc", vim.fn.getcwd(), dir },
    preview_cmd = opencode_preview,
    resume = function(id)
      return "ocr " .. id
    end,
  })
end

return M
