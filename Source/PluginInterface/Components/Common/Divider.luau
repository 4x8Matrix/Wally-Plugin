local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local Divider = Roact.Component:extend("Divider")

Divider.defaultProps = { LayoutOrder = 0 }

--[[
	A one pixel line in Studio's border colour.
]]
function Divider:render()
	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			BackgroundColor3 = palette.divider,
			BorderSizePixel = 0,
			LayoutOrder = self.props.LayoutOrder,
			Size = UDim2.new(1, 0, 0, 1),
		})
	end)
end

return Divider
