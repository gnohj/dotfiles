-- Custom zoxide plugin that searches from YAZI_START_DIR instead of current directory

local function entry()
	local start_dir = os.getenv("YAZI_START_DIR") or ya.target_family() == "windows" and os.getenv("CD") or os.getenv("PWD")

	-- Change to start dir and run zoxide interactive query
	local cmd = string.format(
		"cd '%s' && zoxide query -i",
		start_dir
	)

	local child = Command("sh"):args({ "-c", cmd }):stdin(Command.INHERIT):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()
	if not child then
		return ya.err("Failed to spawn zoxide")
	end

	local output, err = child:wait_with_output()
	if not output then
		return ya.err("Failed to read zoxide output: " .. tostring(err))
	elseif not output.status.success then
		return
	end

	local target = output.stdout:gsub("\n$", "")
	if target == "" then
		return
	end

	ya.manager_emit("cd", { target })
end

return { entry = entry }
