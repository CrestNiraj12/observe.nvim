local function observe()
  return require("observe")
end

local create_command = vim.api.nvim_create_user_command

create_command("ObserveStart", function()
  observe().start()
end, {})

create_command("ObserveStop", function()
  observe().stop()
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

create_command("ObserveTestSpan", function()
  local store = require("observe.core.store")
  store.time("test: busy loop", function()
    local x = 1
    for i = 1, 2e6 do x = x + i end
    return x
  end)
  vim.notify("observe: test span recorded", vim.log.levels.INFO)
end, {})
