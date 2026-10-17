local groups = require("items.widgets.groups")

local NAME <const> = "widgets.uptime"

groups.uptime("system", NAME)

local uptime = sbar.add("item", { drawing = false, updates = true, update_freq = 600 })

local function update()
	sbar.exec("sysctl -n kern.boottime", function(result)
		local boot = tonumber(result:match("sec = (%d+)"))
		if boot then
			sbar.set(NAME, { label = { string = groups.days(os.time() - boot) } })
		end
	end)
end

uptime:subscribe({ "routine", "forced", "system_woke" }, update)
update()
