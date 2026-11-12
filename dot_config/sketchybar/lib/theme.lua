-- Recolours the running bar in place when the palette changes, so a theme switch needs no reload.
local colors = require("config.colors")

-- Every "*color" in a query that holds an old palette rgb, as the same nested table with the new rgb and the alpha kept.
local function remap(node, map)
	local out
	for k, v in pairs(node) do
		local to
		if type(v) == "table" then
			to = remap(v, map)
		elseif type(v) == "string" and type(k) == "string" and k:find("color$") then
			local argb = tonumber(v)
			local rgb = argb and map[argb & 0xffffff]
			to = rgb and (argb & 0xff000000 | rgb)
		end
		if to then
			out = out or {}
			out[k] = to
		end
	end
	return out
end

sbar.add("event", "theme_changed")
local watcher = sbar.add("item", { drawing = false, updates = true })
watcher:subscribe("theme_changed", function()
	local map = colors.reload()
	if next(map) == nil then
		return
	end
	for _, name in ipairs(sbar.query("bar").items) do
		local item = sbar.query(name)
		local props = type(item) == "table" and remap(item, map)
		if props then
			-- A query nests the item's own background under "geometry"; a set does not.
			props.background, props.geometry = props.geometry and props.geometry.background, nil
			sbar.set(name, props)
		end
	end
	-- Defaults are not all queryable, so run the module again against the reloaded palette.
	package.loaded["default"] = nil
	require("default")
end)
