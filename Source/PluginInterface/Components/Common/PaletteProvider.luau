local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local StudioComponents = require(script.Parent.Parent.Parent.Parent.Packages.StudioComponents)

local Palette = require(script.Parent.Parent.Parent.Palette)
local PaletteContext = require(script.Parent.Parent.Parent.PaletteContext)

local PaletteProvider = Roact.Component:extend("PaletteProvider")

PaletteProvider.defaultProps = {}

--[[
	Supplies the palette to everything below it: from Studio's current theme, following theme changes, or from the
		`theme` prop when one is given, which lets a preview show Light beside Dark.
]]
function PaletteProvider:render()
	local children = self.props[Roact.Children]

	if self.props.theme then
		return Roact.createElement(PaletteContext.Provider, { value = Palette.from(self.props.theme) }, children)
	end

	return StudioComponents.withTheme(function(theme)
		return Roact.createElement(PaletteContext.Provider, { value = Palette.from(theme) }, children)
	end)
end

return PaletteProvider
