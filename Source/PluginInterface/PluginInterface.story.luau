local Roact = require(script.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Packages.RoactRodux)
local Rodux = require(script.Parent.Parent.Packages.Rodux)

local Component = require(script.Parent)
local Reducer = require(script.Parent.Reducer)

--[[
	A story for a story viewer: the interface over a store seeded with results, an installed package and an open
		install surface, sized by the frame it is mounted into.
]]
return function(parent)
	local store = Rodux.Store.new(Reducer)

	store:dispatch({ type = "setQuery", query = "signal" })
	store:dispatch({
		type = "setSearch",
		search = {
			status = "done",
			results = {
				{
					scope = "sleitnick",
					name = "signal",
					description = "Signal class with typed connections",
					version = "2.0.3",
				},
				{
					scope = "red-blox",
					name = "signal",
					description = "Fast signals with a familiar API",
					version = "2.0.2",
				},
			},
		},
	})
	store:dispatch({
		type = "setInstalled",
		installed = {
			{
				alias = "Trove",
				realm = "shared",
				scope = "sleitnick",
				name = "trove",
				version = "1.8.0",
				requirement = "^1.6.0",
			},
		},
	})
	store:dispatch({ type = "setSelection", selection = { kind = "result", scope = "sleitnick", name = "signal" } })
	store:dispatch({
		type = "setDetail",
		detail = { status = "done", versions = { "2.0.3", "2.0.2" }, latest = "2.0.3", realms = {} },
	})
	store:dispatch({ type = "setForm", form = { version = "2.0.3", realm = "shared", alias = "Signal" } })

	local handle = Roact.mount(
		Roact.createElement(RoactRodux.StoreProvider, { store = store }, {
			MainInterface = Roact.createElement(Component),
		}),
		parent,
		"PluginInterface"
	)

	return function()
		Roact.unmount(handle)
	end
end
