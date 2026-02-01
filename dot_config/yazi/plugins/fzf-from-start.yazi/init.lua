-- Custom fzf plugin that searches from YAZI_START_DIR instead of current directory

local function entry()
	local start_dir = os.getenv("YAZI_START_DIR") or ya.target_family() == "windows" and os.getenv("CD") or os.getenv("PWD")

	local cmd = string.format(
		"fd -t f -H -E .git . '%s' | fzf --height=100%%",
		start_dir
	)

	local child = Command("sh"):args({ "-c", cmd }):stdin(Command.INHERIT):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()
	if not child then
		return ya.err("Failed to spawn fzf")
	end

	local output, err = child:wait_with_output()
	if not output then
		return ya.err("Failed to read fzf output: " .. tostring(err))
	elseif not output.status.success then
		return
	end

	local target = output.stdout:gsub("\n$", "")
	if target == "" then
		return
	end

	ya.manager_emit("reveal", { target })
end

return { entry = entry }
