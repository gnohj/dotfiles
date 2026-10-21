local M = {}

local function panel(buf)
  local in_pr = vim.api.nvim_buf_get_name(buf):find("atlas://pulls/", 1, true)
  local prefix = in_pr and "atlas.pulls.ui.detail" or "atlas.issues.ui.detail"
  return require(prefix), require(prefix .. ".state")
end

-- Reach the local change_tab(step) so a jump skips loading the tabs in between.
local function jump(detail, step)
  local name, change_tab = debug.getupvalue(detail.next_tab, 1)
  if name == "change_tab" then
    return change_tab(step)
  end
  for _ = 1, step do
    detail.next_tab()
  end
end

local function tab_at(line, col, tabs)
  local from = 1
  for i, tab in ipairs(tabs) do
    local s, e = line:find(tab.label, from, true)
    if not s then
      return nil
    end
    if col < e then
      return i
    end
    from = e + 1
  end
end

local function is_tab_row(buf, row)
  local below = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  return below and below:find("^─") ~= nil
end

local function click()
  local pos = vim.fn.getmousepos()
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  if pos.line == 0 or not is_tab_row(buf, pos.line) then
    return
  end
  local detail, state = panel(buf)
  local line = vim.api.nvim_buf_get_lines(buf, pos.line - 1, pos.line, false)[1]
  local target = tab_at(line, pos.column - 1, state.tabs or {})
  if not target then
    return
  end
  for i, tab in ipairs(state.tabs) do
    if tab.key == state.current_tab and i ~= target then
      return jump(detail, (target - i) % #state.tabs)
    end
  end
end

local navbars, navbar_count = {}, 0

-- navbar emits one span per view, then one per action.
local function record_navbars()
  local navbar = require("atlas.ui.components.navbar")
  local render = navbar.render
  navbar.render = function(opts)
    local result = render(opts)
    local items, segments = opts.items or {}, {}
    for i, span in ipairs(result.highlights) do
      local is_item = i <= #items
      table.insert(segments, {
        start_col = span.start_col,
        end_col = span.end_col,
        kind = is_item and "item" or "action",
        index = is_item and i or i - #items,
        label = is_item and items[i].label
          or (opts.actions or {})[i - #items].label,
      })
    end
    if navbar_count > 20 then
      navbars, navbar_count = {}, 0
    end
    navbars[result.lines[1]] = segments
    navbar_count = navbar_count + 1
    return result
  end
end

local function navbar_click(handlers)
  local pos = vim.fn.getmousepos()
  if pos.line == 0 then
    return
  end
  local buf = vim.api.nvim_win_get_buf(pos.winid)
  local line = vim.api.nvim_buf_get_lines(buf, pos.line - 1, pos.line, false)[1]
  local col = pos.column - 1
  for _, segment in ipairs(navbars[line] or {}) do
    if col >= segment.start_col and col < segment.end_col then
      for dashboard, handler in pairs(handlers) do
        local window = require("atlas." .. dashboard .. ".ui.dashboard.window")
        if window.win() == pos.winid then
          return handler(segment)
        end
      end
    end
  end
end

-- The default tabline draws its close X in the last column of row 1.
local function map_tab_close(buf, detail)
  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    local on_x = pos.screenrow == 1 and pos.screencol == vim.o.columns
    if on_x and #vim.api.nvim_list_tabpages() > 1 and detail().is_open() then
      vim.schedule(detail().close)
      return ""
    end
    return "<LeftMouse>"
  end, { buffer = buf, expr = true, desc = "Tabline X closes the open panel first" })
end

local function open_clicked(dashboard)
  local prefix = "atlas." .. dashboard .. ".ui."
  if
    require(prefix .. "dashboard.navigation").current_item()
    and not require(prefix .. "detail").is_open()
  then
    require(prefix .. "dashboard").toggle_detail()
  end
end

local function map_dashboard_clicks(handlers)
  for dashboard in pairs(handlers) do
    local keymaps = require("atlas." .. dashboard .. ".ui.dashboard.keymaps")
    local register = keymaps.register
    keymaps.register = function(buf, ...)
      register(buf, ...)
      vim.keymap.set("n", "<LeftRelease>", function()
        navbar_click(handlers)
      end, { buffer = buf, desc = "Switch to the clicked view" })
      map_tab_close(buf, function()
        return require("atlas." .. dashboard .. ".ui.detail")
      end)
      vim.keymap.set("n", "<2-LeftMouse>", "<Nop>", { buffer = buf })
      vim.keymap.set("n", "<2-LeftRelease>", function()
        open_clicked(dashboard)
      end, { buffer = buf, desc = "Open the clicked item's detail panel" })
    end
  end
end

function M.setup(handlers)
  record_navbars()
  map_dashboard_clicks(handlers)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "atlas-ui.detail",
    callback = function(ev)
      vim.keymap.set(
        "n",
        "<LeftRelease>",
        click,
        { buffer = ev.buf, desc = "Switch to the clicked tab" }
      )
      map_tab_close(ev.buf, function()
        return (panel(ev.buf))
      end)
    end,
  })
end

return M
