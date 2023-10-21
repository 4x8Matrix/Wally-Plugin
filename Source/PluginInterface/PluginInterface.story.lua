local Roact = require(script.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Packages.RoactRodux)

local RoduxStore = require(script.Parent.Store)
local Component = require(script.Parent)

return function(parent)
	RoduxStore:dispatch({
		["type"] = "setSearchedPackages",
		["packageArray"] = {
			"namespace/package@0.0.0-rc.0",
			"namespace/package@0.0.0-rc.0"
		}
	})

	RoduxStore:dispatch({
		["type"] = "setInstalledPackages",
		["packageArray"] = {
			"namespace/package@0.0.0-rc.0",
			"namespace/package@0.0.0-rc.0",
		}
	})

	local handle = Roact.mount(
		Roact.createElement(RoactRodux.StoreProvider, {
			store = RoduxStore,
		}, {
			MainInterface = Roact.createElement(Component, {}),
		}),
		parent,
		"PluginInterface"
	)

	local thread = task.spawn(function()
		while true do
			task.wait(5)

			RoduxStore:dispatch({
				["type"] = "setLoadingState",
				["state"] = not RoduxStore:getState().isLoading
			})
		end
	end)

	return function()
		Roact.unmount(handle)
		task.cancel(thread)
	end
end
