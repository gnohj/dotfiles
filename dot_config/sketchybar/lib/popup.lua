local M = {}

local closeOthers <const> = "~/.config/sketchybar/items/widgets/popup-close-others.sh"

-- The owner list lives in that script alone, shared with the shell click scripts.
function M.close_others(name)
	sbar.exec(closeOthers .. " " .. name)
end

-- For panels with no rows of their own to carry the open along.
function M.open_exclusive(name)
	sbar.exec(closeOthers .. " " .. name .. " && sketchybar --set " .. name .. " popup.drawing=on")
end

-- max_chars truncates without an ellipsis, and byte-based cutting would split multibyte apostrophes.
function M.ellipsize(text, limit)
	local n = utf8.len(text)
	if not n or n <= limit then
		return text
	end
	return text:sub(1, utf8.offset(text, limit) - 1) .. "…"
end

local function shq(s)
	return "'" .. (tostring(s):gsub("'", "'\\''")) .. "'"
end

local function props(prefix, t, out)
	if t == nil then
		return
	end
	if t.string ~= nil then
		out[#out + 1] = prefix .. "=" .. shq(t.string)
	end
	if t.color ~= nil then
		out[#out + 1] = prefix .. ".color=" .. string.format("0x%08x", t.color)
	end
	if t.width ~= nil then
		out[#out + 1] = prefix .. ".width=" .. math.floor(t.width)
	end
	if t.align ~= nil then
		out[#out + 1] = prefix .. ".align=" .. t.align
	end
	if t.drawing ~= nil then
		out[#out + 1] = prefix .. ".drawing=" .. (t.drawing and "on" or "off")
	end
	if t.font ~= nil then
		if t.font.size then
			out[#out + 1] = prefix .. ".font.size=" .. t.font.size
		end
		if t.font.style then
			out[#out + 1] = prefix .. ".font.style=" .. shq(t.font.style)
		end
	end
end

-- The whole panel in one `sketchybar -m`, the way the mic panel builds its popup.
function M.build(parent, removePattern, rows, open)
	local args = { "sketchybar -m" }
	if removePattern then
		args[#args + 1] = "--remove " .. shq(removePattern)
	end
	-- Opened separately, sketchybar lays the popup out while empty and never re-lays it out: a blank panel.
	if open then
		args[#args + 1] = "--set " .. parent .. " popup.drawing=on"
	end
	for _, row in ipairs(rows) do
		args[#args + 1] = "--add item " .. row.name .. " popup." .. parent
		args[#args + 1] = "--set " .. row.name
		props("icon", row.icon, args)
		props("label", row.label, args)
		if row.click_script ~= nil and row.click_script ~= "" then
			args[#args + 1] = "click_script=" .. shq(row.click_script)
		end
	end
	sbar.exec(table.concat(args, " "))
end

return M
