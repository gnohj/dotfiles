local colors = require("config.colors")

local M = {}

M.cpu = { { at = 90, color = colors.red }, { at = 75, color = colors.orange }, { at = 60, color = colors.yellow } }
M.usage = { { at = 90, color = colors.red }, { at = 80, color = colors.orange }, { at = 70, color = colors.yellow } }

function M.color(value, steps, default)
	local number = tonumber(value)
	if number then
		for _, step in ipairs(steps) do
			if number >= step.at then
				return step.color
			end
		end
	end
	return default
end

return M
