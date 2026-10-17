local constants = require("constants")
local settings = require("config.settings")

local CLI = "/opt/homebrew/bin/rift-cli"
local LAYOUT = os.getenv("HOME") .. "/.local/libexec/rift-layout"

local modes <const> = {
	bsp = { icon = utf8.char(0xF0574), label = "BSP", color = settings.colors.cyan },
	traditional = { icon = utf8.char(0xF0BCC), label = "TILE", color = settings.colors.blue },
	stack = { icon = utf8.char(0xF0328), label = "STACK", color = settings.colors.magenta },
	master_stack = { icon = utf8.char(0xF056E), label = "MASTER", color = settings.colors.yellow },
	scrolling = { icon = utf8.char(0xF056C), label = "SCROLL", color = settings.colors.green },
	floating = { icon = utf8.char(0xF10AC), label = "FLOAT", color = settings.colors.red },
}

local bound <const> = {
	{ mode = "bsp", key = "/" },
	{ mode = "traditional", key = ";" },
	{ mode = "stack", key = "," },
	{ mode = "scrolling", key = "." },
	{ mode = "floating", key = "'" },
}

sbar.add("event", constants.events.RIFT_LAYOUT_CHANGED)

local function add_pill(name)
	return sbar.add("item", name, {
		position = "left",
		drawing = false,
		icon = { font = { size = 14.0 }, padding_left = 10, padding_right = 5 },
		label = { font = { style = settings.fonts.styles.bold, size = 14.0 }, padding_left = 0, padding_right = 11 },
		background = { height = 24, corner_radius = 12, border_width = 1 },
		padding_left = 3,
		padding_right = 3,
	})
end

-- 3px plus the first pill's own 3px matches the 6px between every other badge.
local gap = sbar.add("item", constants.items.RIFT_LAYOUT .. ".gap", {
	position = "left",
	width = 3,
	icon = { drawing = false },
	label = { drawing = false },
	padding_left = 0,
	padding_right = 0,
})

local pills = {}
for _, b in ipairs(bound) do
	pills[#pills + 1] = {
		mode = b.mode,
		key = b.key,
		item = add_pill(constants.items.RIFT_LAYOUT .. "." .. b.mode),
	}
end
local extra = add_pill(constants.items.RIFT_LAYOUT .. ".other")

local shown = true
local expanded = true
local current

local function paint(item, style, text, active)
	local color = active and style.color or settings.colors.dark_grey
	item:set({
		drawing = shown and (expanded or active),
		icon = { string = style.icon, color = color },
		label = { string = text, color = color },
		background = {
			color = settings.colors.transparent,
			border_color = settings.colors.with_alpha(settings.colors.dark_grey, 0.5),
		},
	})
end

local arrows <const> = {
	horizontal = " " .. utf8.char(0x2194),
	horizontal_stack = " " .. utf8.char(0x2194),
	vertical = " " .. utf8.char(0x2195),
	vertical_stack = " " .. utf8.char(0x2195),
}

local oriented <const> = { bsp = true, traditional = true, stack = true }

local FULLSCREEN = " " .. utf8.char(0xF0293)

local function render(active, kind, fullscreen)
	local arrow = fullscreen and FULLSCREEN or (oriented[active] and arrows[kind] or "")
	local chevron = expanded and " 󰄽" or " 󰄾"
	current = active
	for _, p in ipairs(pills) do
		local is_active = p.mode == active
		local text = modes[p.mode].label .. (is_active and arrow or "") .. " " .. utf8.char(0xF0635) .. " " .. p.key
		paint(p.item, modes[p.mode], text .. (is_active and chevron or ""), is_active)
	end
	local other = modes[active]
	local is_bound = false
	for _, p in ipairs(pills) do
		is_bound = is_bound or p.mode == active
	end
	if other and not is_bound then
		paint(extra, other, other.label .. arrow .. chevron, true)
	else
		extra:set({ drawing = false })
	end
end

local function find_selected(node, parent)
	if type(node) ~= "table" then
		return nil
	end
	if node.node_type == "window" and node.is_selected then
		return node, parent
	end
	for _, child in ipairs(node.children or {}) do
		local found, found_parent = find_selected(child, node)
		if found then
			return found, found_parent
		end
	end
	return nil
end

local function refresh()
	sbar.exec(CLI .. " query layout 2>/dev/null", function(layout)
		if type(layout) ~= "table" or not layout.mode then
			return
		end
		local selected, parent = find_selected(layout.container_tree)
		local fullscreen = selected and (selected.is_fullscreen or selected.is_fullscreen_within_gaps)
		render(layout.mode, parent and parent.layout_kind, fullscreen)
	end)
end

local watcher = sbar.add("item", { drawing = false, updates = true })
watcher:subscribe({ constants.events.RIFT_LAYOUT_CHANGED, constants.events.RIFT_WORKSPACE_CHANGED }, refresh)
watcher:subscribe(constants.events.SWAP_MENU_AND_SPACES, function(env)
	shown = env.isShowingMenu ~= "on"
	gap:set({ drawing = shown })
	refresh()
end)

local function toggle()
	expanded = not expanded
	refresh()
end

for _, p in ipairs(pills) do
	p.item:subscribe("mouse.clicked", function()
		if p.mode == current then
			return toggle()
		end
		sbar.exec(LAYOUT .. " " .. p.mode, refresh)
	end)
end
extra:subscribe("mouse.clicked", toggle)
sbar.add("event", "rift_layout_toggle")
watcher:subscribe("rift_layout_toggle", toggle)

refresh()

