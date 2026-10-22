local Roact = require(script.Parent.Packages.Roact)

local PaletteProvider = require(script.Components.Common.PaletteProvider)
local Shelf = require(script.Components.Shelf)

local MainInterface = Roact.Component:extend("MainInterface")

MainInterface.defaultProps = {}

--[[
	The widget's root: the palette from Studio's theme around the Shelf interface.
]]
function MainInterface:render()
	return Roact.createElement(PaletteProvider, { theme = self.props.theme }, {
		Shelf = Roact.createElement(Shelf, { LayoutSize = self.props.LayoutSize }),
	})
end

return MainInterface
