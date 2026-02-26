local function observe()
	return require("observe")
end

local create_command = vim.api.nvim_create_user_command

create_command("ObserveStart", function()
	observe().start()
end, {})

create_command("ObserveStop", function()
	observe().stop()
	observe().report()
end, {})

create_command("ObserveReport", function()
	observe().report()
end, {})

create_command("ObserveToggle", function()
	local obs = observe()
	if obs.is_enabled() then
		obs.stop()
	else
		obs.start()
	end
end, {})
