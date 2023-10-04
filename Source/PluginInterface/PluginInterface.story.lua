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

	return function()
		Roact.unmount(handle)
	end
end
