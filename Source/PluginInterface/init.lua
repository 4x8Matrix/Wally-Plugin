local Roact = require(script.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Packages.RoactRodux)
local StudioComponents = require(script.Parent.Packages.StudioComponents)

local InstalledPackages = require(script.Components.InstalledPackages)
local PackageSearch = require(script.Components.PackageSearch)
local Loading = require(script.Components.Loading)

local MainInterface = Roact.Component:extend("MainInterface")

function MainInterface:render()
	return Roact.createElement(StudioComponents.Background, {
		Size = UDim2.fromScale(1, 1)
	}, {
		PluginScrollFrame = Roact.createElement(StudioComponents.ScrollFrame, {
			Size = UDim2.fromScale(1, 1),
			Layout = {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 5),
			}
		}, {
			InstalledPackages = Roact.createElement(InstalledPackages, {
				HeaderText = "Installed Wally Packages"
			}),

			PackageSearch = Roact.createElement(PackageSearch, {
				HeaderText = "Search Wally Packages"
			}),
		}),

		Loading = self.props.store.isLoading and Roact.createElement(Loading)
	})
end

return RoactRodux.connect(function(state)
	return {
		store = state,
	}
end)(MainInterface)
