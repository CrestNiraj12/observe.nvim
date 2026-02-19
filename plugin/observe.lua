local function observe()
  return require("observe")
end

vim.api.nvim_create_user_command("ObserveStart", function()
  observe().start()
end, {})

vim.api.nvim_create_user_command("ObserveStop", function()
  observe().stop()
end, {})

vim.api.nvim_create_user_command("ObserveReport", function()
  observe().report()
end, {})

vim.api.nvim_create_user_command("ObserveToggle", function()
  local obs = observe()
  if obs.is_enabled() then
    obs.stop()
  else
    obs.start()
  end
end, {})
