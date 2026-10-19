local M = {}

local cache_root = vim.fn.stdpath("cache") .. "/atlas-attachments"

local function human_size(bytes)
  local units, size, unit = { "B", "KB", "MB", "GB" }, bytes or 0, 1
  while size >= 1024 and unit < #units do
    size, unit = size / 1024, unit + 1
  end
  return unit == 1 and string.format("%d %s", size, units[unit])
    or string.format("%.1f %s", size, units[unit])
end

local function icon(mime)
  local kind = (mime or ""):match("^(%a+)/") or ""
  return ({ image = "󰋩", video = "󰕧", audio = "󰎆", text = "󰈙" })[kind]
    or "󰈔"
end

local function cached_path(attachment)
  local name = attachment.filename:gsub("[/\\]", "_")
  return string.format("%s/%s/%s", cache_root, attachment.id, name)
end

local function download(attachment, path, on_done)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local auth = string.format(
    'user = "%s:%s"\n',
    vim.env.JIRA_EMAIL,
    vim.env.JIRA_API_TOKEN
  )
  local args = { "curl", "-sSfL", "-K", "-", "-o", path, attachment.content }
  vim.system(args, { stdin = auth, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        os.remove(path)
        return on_done(
          vim.trim(res.stderr ~= "" and res.stderr or "download failed")
        )
      end
      on_done(nil)
    end)
  end)
end

local function ensure(attachment, on_ready)
  if not (vim.env.JIRA_EMAIL and vim.env.JIRA_API_TOKEN) then
    return on_ready(nil, "JIRA_EMAIL / JIRA_API_TOKEN not set")
  end
  local path = cached_path(attachment)
  local stat = vim.uv.fs_stat(path)
  if stat and stat.size == attachment.size then
    return on_ready(path)
  end
  download(attachment, path, function(err)
    on_ready(not err and path or nil, err)
  end)
end

function M.open(attachment)
  local path = cached_path(attachment)
  local stat = vim.uv.fs_stat(path)
  if not (stat and stat.size == attachment.size) then
    vim.notify("Downloading " .. attachment.filename)
  end
  ensure(attachment, function(ready, err)
    if not ready then
      return vim.notify(
        attachment.filename .. ": " .. err,
        vim.log.levels.ERROR
      )
    end
    vim.ui.open(ready)
  end)
end

local hover

function M.close_preview()
  if hover then
    if hover.win then
      hover.win:close()
    end
    if hover.img then
      hover.img:close()
    end
    hover = nil
  end
end

local function previewable(attachment)
  local image = Snacks and Snacks.image
  return attachment
    and (attachment.mimeType or ""):match("^image/")
    and image
    and image.supports_terminal()
    and image.supports_file(attachment.filename)
end

-- Full-size screenshots never reach the screen through herdr, so float a small normalized copy.
local function preview_copy(path, on_ready)
  local preview = vim.fs.dirname(path) .. "/preview.png"
  if vim.uv.fs_stat(preview) then
    return on_ready(preview)
  end
  local args = { "magick", path, "-resize", "1600x1600>", "-strip", preview }
  vim.system(args, {}, function(res)
    vim.schedule(function()
      on_ready(res.code == 0 and preview or nil)
    end)
  end)
end

local function show_preview(path)
  -- Snacks never re-sends an image it sent once, but the terminal drops them across focus changes.
  require("snacks.image.image").new(path).sent = false
  local doc = Snacks.image.config.doc
  local win = Snacks.win(Snacks.win.resolve(doc, "snacks_image", {
    show = false,
    enter = false,
  }))
  win:open_buf()
  local shown = false
  hover.win = win
  hover.img = Snacks.image.placement.new(
    win.buf,
    path,
    Snacks.config.merge({}, doc, {
      inline = false,
      on_update_pre = function()
        if hover and hover.win == win and not shown then
          shown = true
          local loc = hover.img:state().loc
          win.opts.width, win.opts.height = loc.width, loc.height
          win:show()
        end
      end,
    })
  )
end

function M.preview(attachment)
  if not previewable(attachment) then
    return M.close_preview()
  end
  if hover and hover.id == attachment.id then
    return
  end
  M.close_preview()
  local current = { id = attachment.id }
  hover = current
  ensure(attachment, function(path)
    if not path then
      return
    end
    preview_copy(path, function(preview)
      if preview and hover == current then
        show_preview(preview)
      end
    end)
  end)
end

function M.append(lines, highlights, line_map, attachments)
  if not attachments or #attachments == 0 then
    return
  end
  vim.list_extend(lines, { "", " Attachments", "" })
  table.insert(highlights, {
    line = #lines - 2,
    start_col = 1,
    end_col = #lines[#lines - 1],
    hl_group = "Title",
  })
  for _, attachment in ipairs(attachments) do
    local name =
      string.format(" %s %s", icon(attachment.mimeType), attachment.filename)
    table.insert(
      lines,
      string.format("%s  %s", name, human_size(attachment.size))
    )
    table.insert(highlights, {
      line = #lines - 1,
      start_col = 1,
      end_col = #name,
      hl_group = "Underlined",
    })
    table.insert(highlights, {
      line = #lines - 1,
      start_col = #name,
      end_col = #lines[#lines],
      hl_group = "Comment",
    })
    line_map[#lines] = { attachment = attachment }
  end
end

function M.at_line(entry, line, attachments)
  if entry and entry.attachment then
    return entry.attachment
  end
  for _, attachment in ipairs(attachments or {}) do
    if line:find(attachment.filename, 1, true) then
      return attachment
    end
  end
end

return M
