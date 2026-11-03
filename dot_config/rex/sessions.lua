-- Session actions: switching, last-session toggle, and closing back to the session last left.
local c = require("common")

local M = {}

-- Keyboard session switches record the two sessions last left, as rex-herdr ids (<host>~<id> for another host), for ctrl+enter.
local function session_ref(ctx)
  if ctx.session_id == nil then return nil end
  local id = (ctx.session_id:gsub("^session:", ""))
  if type(ctx.server) == "string" then return (ctx.server:gsub("[^%w]", "-")) .. "~" .. id end
  return id
end

local function left_sessions()
  local f = io.open(c.STATE_DIR .. "/left-sessions")
  if f == nil then return {} end
  local refs = {}
  for line in f:lines() do
    if line ~= "" then table.insert(refs, line) end
  end
  f:close()
  return refs
end

function M.leave_session(ctx)
  local here, refs = session_ref(ctx), left_sessions()
  if here ~= nil and refs[1] ~= here then c.write_state("left-sessions", here .. "\n" .. (refs[1] or "")) end
end

-- The session last left by keyboard that still exists other than `here`; bare refs can only be checked from this host.
local function previous_session(here, on_this_host)
  local live = nil
  if on_this_host then
    live = {}
    for _, s in ipairs((rex.call("session.list") or {}).sessions or {}) do live[(s.session_id:gsub("^session:", ""))] = true end
  end
  for _, ref in ipairs(left_sessions()) do
    if ref ~= here and (live == nil or ref:find("~", 1, true) or live[ref]) then return ref end
  end
end

local function go_to_session(ctx, target)
  if ctx.server == nil and not target:find("~", 1, true) then
    rex.client.queue("session.select", { session_id = "session:" .. target })
    return
  end
  c.fail(select(2, rex.exec.start({ "/bin/zsh", "-lc", 'exec "$HOME/.local/bin/mux/rex/rex-herdr" workspace focus "$0"', target },
                                  { detach = true, env = c.REX_ENV })))
end

-- Closing a session returns to the one last left, on either host, instead of the neighbour Rex picks; the closed one leaves the history.
local function return_from(ctx, here)
  local target, kept = previous_session(here, ctx.server == nil), {}
  for _, ref in ipairs(left_sessions()) do
    if ref ~= here then table.insert(kept, ref) end
  end
  c.write_state("left-sessions", table.concat(kept, "\n"))
  if target ~= nil then go_to_session(ctx, target) end
end

function M.close_session(ctx)
  local here = session_ref(ctx)
  c.fail(select(2, rex.call("session.destroy", { session_id = ctx.session_id })))
  return_from(ctx, here)
end

function M.setup()
  rex.action{
    name = "switch_session",
    title = "Switch Session",
    category = "Sessions",
    args = { action = "string" },
    run = function(ctx, args)
      M.leave_session(ctx)
      rex.client.queue(args.action)
    end,
  }

  -- herdr hack-herdr-last-workspace.sh; Rex sends no event for a mouse switch, so rex-last-session.lua ranks sessions by when the app last showed them.
  rex.action{
    name = "last_session",
    title = "Last Session Toggle",
    category = "Sessions",
    run = function(ctx, args)
      M.leave_session(ctx)
      c.fail(select(2, rex.exec.start({ "/bin/zsh", "-lc", 'exec "${REX_BIN_DIR:+$REX_BIN_DIR/}rex" --autostart=false do "$HOME/.local/bin/mux/rex/rex-last-session.lua" client="$0" session="$1"',
                                        ctx.client_id or "", ctx.session_id or "" }, { detach = true, env = c.REX_ENV })))
    end,
  }

  -- herdr-next-priority-agent.sh across hosts: rex-attention.lua scans the Mac and every `rex hosts` entry.
  rex.action{
    name = "next_attention",
    title = "Next Agent Needing Attention",
    category = "Sessions",
    run = function(ctx, args)
      M.leave_session(ctx)
      c.fail(select(2, rex.exec.start({ "/bin/zsh", "-lc", 'exec "${REX_BIN_DIR:+$REX_BIN_DIR/}rex" --autostart=false do "$HOME/.local/bin/mux/rex/rex-attention.lua" host="$0" block="$1"',
                                        type(ctx.server) == "string" and ctx.server or "", ctx.block_id or "" }, { detach = true, env = c.REX_ENV })))
    end,
  }

  -- Called by rex-herdr before the picker deletes the session it runs in; the CLI names no host, so the ref is found by id.
  rex.action{
    name = "return_from_session",
    title = "Return From a Closing Session",
    category = "Sessions",
    args = { session_id = "string" },
    run = function(ctx, args)
      local id = (args.session_id:gsub("^session:", ""))
      local here = id
      for _, ref in ipairs(left_sessions()) do
        if ref == id or ref:sub(-#id - 1) == "~" .. id then here = ref end
      end
      return_from(ctx, here)
    end,
  }

  rex.action{
    name = "close_session",
    title = "Close Session and Return to the Last",
    category = "Sessions",
    run = function(ctx, args) M.close_session(ctx) end,
  }

  -- Closing the only tab closes the session, so it takes the same way back.
  rex.action{
    name = "close_tab",
    title = "Close Tab or Last-Tab Session",
    category = "Sessions",
    run = function(ctx, args)
      if #c.windows().windows > 1 then
        rex.client.queue("client.tab.close")
        return
      end
      M.close_session(ctx)
    end,
  }
end

return M
