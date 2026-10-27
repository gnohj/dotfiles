-- cmd+shift+v: copied files or a copied image land on the pane's host and are pasted as paths (upload after pablasso/rex-image-paste, MIT).
local c = require("common")

local M = {}

local STAGE = (os.getenv("TMPDIR") or "/tmp"):gsub("/+$", "") .. "/rex-paste"
local MAX_IMAGE = 2000
local SSH_ABOVE = 4 * 1024 * 1024
local CHUNK = 56 * 1024
local TIMEOUT = 25

-- Rex host label -> ssh alias, used for files too big to stream through Rex in under 30 seconds.
M.ssh = { ["Dev Box"] = "fleet-dev-box" }
M.pasteboard = nil

-- Prints "file\t<path>" per copied file, "png"/"tiff" after saving image data to argv[0].<kind>, else "none".
local CLIPBOARD_JS = [=[
ObjC.import('AppKit');
function run(argv) {
  const pb = argv[1] ? $.NSPasteboard.pasteboardWithName(argv[1]) : $.NSPasteboard.generalPasteboard;
  const opts = $.NSDictionary.dictionaryWithObjectForKey(true, $.NSPasteboardURLReadingFileURLsOnlyKey);
  const urls = pb.readObjectsForClassesOptions($([$.NSURL]), opts);
  if (urls && !urls.isNil() && urls.count > 0) {
    const out = [];
    for (let i = 0; i < urls.count; i++) out.push('file\t' + ObjC.unwrap(urls.objectAtIndex(i).path));
    return out.join('\n');
  }
  for (const [type, kind] of [[$.NSPasteboardTypePNG, 'png'], [$.NSPasteboardTypeTIFF, 'tiff']]) {
    const data = pb.dataForType(type);
    if (data.isNil()) continue;
    if (!data.writeToFileAtomically(argv[0] + '.' + kind, true)) throw new Error('cannot write ' + argv[0]);
    return kind;
  }
  return 'none';
}
]=]

-- Runs on the pane's host: reuses a same-checksum copy, else reads base64 typed into a hidden terminal (rex) or raw stdin (ssh).
local RECEIVE = [=[
umask 077
key=$1 name=$2 mode=$3
hold() { [ "$mode" = ssh ] || sleep 60; }
d="${TMPDIR:-/tmp}/rex-paste-$(id -u)"
mkdir -p "$d" && [ -O "$d" ] && chmod 700 "$d" || { echo "REXPASTE-ERR cannot use $d"; hold; exit 1; }
find "$d" -mindepth 2 -type f -mmin +1440 -delete 2>/dev/null
find "$d" -mindepth 1 -type d -empty -delete 2>/dev/null
f="$d/$key/$name" t="$d/$key/.$name.part.$$"
[ -s "$f" ] || for o in "$d/$key"/*; do [ -s "$o" ] && cp "$o" "$f" && break; done
[ -s "$f" ] && { touch "$f"; printf 'REXPASTE-HIT %s\n' "$f"; hold; exit 0; }
mkdir -p "$d/$key" || { echo "REXPASTE-ERR cannot use $d/$key"; hold; exit 1; }
trap 'rm -f "$t"' EXIT
if [ "$mode" = ssh ]; then
  cat > "$t"
else
  stty -echo 2>/dev/null
  ( sleep 120; kill 0 ) 2>/dev/null &
  base64 -d > "$t"
fi && mv "$t" "$f" &&
  printf 'REXPASTE-OK %s %s\n' "$( (sha256sum "$f" 2>/dev/null || shasum -a 256 "$f") | cut -d' ' -f1)" "$f" ||
  echo "REXPASTE-ERR could not write $f"
hold
]=]

local function fail(message)
  error("paste: " .. message, 0)
end

local function exec(argv, opts)
  local r, err = rex.exec(argv, opts)
  if r == nil then fail(argv[1] .. ": " .. tostring(err)) end
  if not r.ok then fail(argv[1] .. ": " .. (r.stderr ~= "" and r.stderr or ("exit " .. r.code))) end
  return r.stdout
end

local function sleep(seconds)
  if rex.sleep then return rex.sleep(seconds) end
  rex.exec({ "sleep", tostring(seconds) })
end

local function sha256(path)
  return exec({ "shasum", "-a", "256", path }):match("^(%x+)")
end

local function size(path)
  return tonumber(exec({ "stat", "-f", "%z", path }):match("%d+")) or 0
end

-- Agents attach pasted paths escaped the way a terminal escapes a dropped file.
local function escape(path)
  return (path:gsub("([^%w%._/%-+@,:=~])", "\\%1"))
end

local function sh_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Clipboard image data becomes one PNG no larger than MAX_IMAGE on its long edge; copied files travel untouched.
local function image_as_png(src, base)
  local info = exec({ "sips", "-g", "pixelWidth", "-g", "pixelHeight", src })
  local long = math.max(tonumber(info:match("pixelWidth: (%d+)")) or 0, tonumber(info:match("pixelHeight: (%d+)")) or 0)
  local out = base .. ".png"
  if long <= MAX_IMAGE and src == out then return out end
  local argv = { "sips", "-s", "format", "png" }
  if long > MAX_IMAGE then
    argv[#argv + 1] = "-Z"
    argv[#argv + 1] = tostring(MAX_IMAGE)
  end
  for _, a in ipairs({ src, "--out", out .. ".tmp.png" }) do argv[#argv + 1] = a end
  exec(argv, { timeout = 10 })
  os.remove(src)
  os.rename(out .. ".tmp.png", out)
  return out
end

-- Returns the copied files, or the clipboard image saved as a staged PNG (staged = true), or nothing.
local function read_clipboard()
  exec({ "mkdir", "-p", STAGE })
  rex.exec({ "find", STAGE, "-type", "f", "-mmin", "+1440", "-delete" })
  local base = STAGE .. "/clipboard-" .. os.date("%Y%m%d-%H%M%S")
  local argv = { "osascript", "-l", "JavaScript", "-e", CLIPBOARD_JS, base }
  if M.pasteboard then argv[#argv + 1] = M.pasteboard end
  local out = exec(argv, { timeout = 5 })
  local files = {}
  for path in out:gmatch("file\t([^\n]+)") do
    local dir = rex.exec({ "test", "-d", path })
    if dir and dir.ok then fail("folders can't be pasted: " .. path) end
    files[#files + 1] = path
  end
  if #files > 0 then return files, false end
  local kind = out:match("^(%a+)")
  if kind == "png" or kind == "tiff" then return { image_as_png(base .. "." .. kind, base) }, true end
  return files, false
end

local function block_method(api, session_id, block_id, method, args)
  return api.call("block.method", { session_id = session_id, block_id = block_id, method = method, args = args or {} })
end

-- Streams the file as base64 into a hidden terminal on the pane's host, then reads back the result line.
local function send_over_rex(api, session_id, key, name, src, deadline)
  local opened, err = api.call("session.new_block", {
    session_id = session_id,
    flavor = c.SHELL,
    label = "rex-paste",
    options = { shell = "none", command = { "sh", "-c", RECEIVE, "rex-paste", key, name, "rex" }, size = { columns = 400, rows = 10 } },
  })
  if opened == nil then fail("start upload terminal: " .. tostring(err)) end
  local block_id = opened.block_id

  local function screen()
    local s = block_method(api, session_id, block_id, "format", { trim = true, unwrap = true })
    local text = s and s.content or ""
    local why = text:match("REXPASTE%-ERR ([^\r\n]+)")
    if why then fail(why) end
    return text
  end
  local function check_time(doing)
    if os.time() >= deadline then fail("gave up " .. doing .. " after " .. TIMEOUT .. "s") end
  end

  local ok, result = pcall(function()
    while true do
      local mode = block_method(api, session_id, block_id, "input_mode")
      if mode and mode.echo == false then break end
      local hit = screen():match("REXPASTE%-HIT ([^\r\n]+)")
      if hit then return { path = hit } end
      check_time("starting the upload")
      sleep(0.02)
    end
    local encoded = exec({ "base64", "-b", "76", "-i", src })
    for i = 1, #encoded, CHUNK do
      if block_method(api, session_id, block_id, "write", { data = encoded:sub(i, i + CHUNK - 1) }) == nil then fail("upload: write failed") end
      check_time(string.format("uploading %s (%d of %d KiB)", name, math.floor(i / 1024), math.floor(#encoded / 1024)))
    end
    block_method(api, session_id, block_id, "write", { data = "\n\004" })
    while true do
      local sum, path = screen():match("REXPASTE%-OK (%x+) ([^\r\n]+)")
      if sum then return { path = path, sum = sum } end
      check_time("waiting for " .. name)
      sleep(0.05)
    end
  end)
  api.call("block.close", { session_id = session_id, block_id = block_id })
  if not ok then error(result, 0) end
  return result
end

-- One ssh call: the remote side exits early on a checksum hit, otherwise it reads the file from stdin.
local function send_over_ssh(alias, key, name, src, deadline)
  local remote = table.concat({ "sh", "-c", sh_quote(RECEIVE), "rex-paste", sh_quote(key), sh_quote(name), "ssh" }, " ")
  local r, err = rex.exec({ "/bin/sh", "-c", 'f=$1; shift; exec ssh -o BatchMode=yes -o ConnectTimeout=5 "$@" < "$f"', "sh", src, alias, remote },
    { timeout = math.max(1, deadline - os.time()) })
  if r == nil then fail("ssh: " .. tostring(err)) end
  local why = r.stdout:match("REXPASTE%-ERR ([^\r\n]+)")
  if why then fail(why) end
  local hit = r.stdout:match("REXPASTE%-HIT ([^\r\n]+)")
  if hit then return { path = hit } end
  local sum, path = r.stdout:match("REXPASTE%-OK (%x+) ([^\r\n]+)")
  if sum then return { path = path, sum = sum } end
  fail("ssh " .. alias .. ": " .. (r.timed_out and ("gave up uploading " .. name .. " after " .. TIMEOUT .. "s") or (r.stderr ~= "" and r.stderr or ("exit " .. r.code))))
end

function M.paste(ctx)
  if not ctx.session_id or not ctx.block_id then fail("no focused terminal") end
  local files, staged = read_clipboard()
  if #files == 0 then return { pasted = 0 } end

  local api = ctx.server and rex.server(ctx.server) or rex
  local deadline = os.time() + TIMEOUT
  local paths, reused = {}, 0
  for _, src in ipairs(files) do
    if not ctx.server then
      paths[#paths + 1] = src
    else
      local sum = sha256(src)
      local name = src:match("([^/]+)$")
      local alias = M.ssh[ctx.server]
      local sent
      if alias and size(src) > SSH_ABOVE then
        sent = send_over_ssh(alias, sum:sub(1, 16), name, src, deadline)
      else
        sent = send_over_rex(api, ctx.session_id, sum:sub(1, 16), name, src, deadline)
      end
      if sent.sum and sent.sum ~= sum then fail("checksum mismatch for " .. sent.path) end
      if not sent.sum then reused = reused + 1 end
      if staged then os.remove(src) end
      paths[#paths + 1] = sent.path
    end
  end

  local text = {}
  for i, p in ipairs(paths) do text[i] = escape(p) end
  local pasted, err = api.call("block.event", {
    session_id = ctx.session_id,
    block_id = ctx.block_id,
    event = { type = "paste", payload = { text = table.concat(text, " ") } },
  })
  if pasted == nil then fail("paste: " .. tostring(err)) end
  return { pasted = #paths, paths = paths, reused = reused, server = ctx.server }
end

-- Only the Mac's server can read its clipboard, so a Linux server skips the action and its key.
function M.setup()
  local os_name = rex.exec({ "uname", "-s" })
  if not (os_name and os_name.stdout:match("^Darwin")) then return false end
  rex.action{
    name = "file_paste",
    title = "Paste Copied Files as Paths",
    description = "Paste the files copied in Finder, or the clipboard's image, as paths. In a pane on another server, they are copied there first.",
    category = "Clipboard",
    keywords = "clipboard file image screenshot upload agent remote",
    run = function(ctx) return M.paste(ctx) end,
  }
  return true
end

return M
