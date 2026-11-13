local M = {}

local TTL_SECONDS = 60
local cache = {}

local STATE_HL = {
  OPEN = "AtlasPROpenChip",
  MERGED = "AtlasPRMergedChip",
  DECLINED = "AtlasPRDeclinedChip",
}

local function refresh(issue)
  local key = issue.key
  cache[key] = { prs = cache[key] and cache[key].prs, at = os.time() }
  require("config.atlas.mux-jump").dev_panel_prs(issue.id, function(prs)
    vim.schedule(function()
      cache[key] = { prs = prs, at = os.time() }
      local state = require("atlas.issues.ui.detail.state")
      if state.current_issue and state.current_issue.key == key then
        require("atlas.issues.ui.detail.renderer").render()
      end
    end)
  end)
end

local function count(prs, status)
  return #vim.tbl_filter(function(pr)
    return pr.status == status
  end, prs)
end

function M.chip(issue)
  if not (issue and issue.key and issue.id) then
    return nil
  end
  local entry = cache[issue.key]
  if not entry or os.time() - entry.at > TTL_SECONDS then
    refresh(issue)
  end
  local prs = cache[issue.key].prs
  if not prs or #prs == 0 then
    return nil
  end
  local icon = require("atlas.ui.shared.icons").provider_icon("github", "pulls")
  local open = count(prs, "OPEN")
  local status = open > 0 and "OPEN"
    or count(prs, "MERGED") > 0 and "MERGED"
    or prs[1].status
  local text
  if #prs == 1 then
    local number = prs[1].url:match("/pull/(%d+)")
    text = string.format("#%s %s", number, status:lower())
  else
    text = string.format("%d PRs · %d open", #prs, open)
  end
  return {
    label = icon .. " " .. text .. " (X)",
    hl = STATE_HL[status] or "AtlasRelatedChip",
  }
end

return M
