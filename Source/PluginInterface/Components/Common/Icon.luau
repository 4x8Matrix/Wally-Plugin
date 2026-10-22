local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)

local Palette = require(script.Parent.Parent.Parent.Palette)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local WHITE = Color3.new(1, 1, 1)

local Icon = Roact.Component:extend("Icon")

Icon.defaultProps = {
	Image = "",
	Size = 16,
	Role = "sub",
	Tinted = true,
	Rotation = 0,
	Transparency = 0,
	Position = UDim2.new(),
	AnchorPoint = Vector2.zero,
	LayoutOrder = 0,
}

--[[
	One of Studio's built-in icons. White icons are tinted with their role's colour; coloured ones are drawn as
		shipped when `Tinted` is false.
]]
function Icon:render()
	local props = self.props

	return withPalette(function(palette)
		return Roact.createElement("ImageLabel", {
			AnchorPoint = props.AnchorPoint,
			BackgroundTransparency = 1,
			Image = props.Image,
			ImageColor3 = if props.Tinted then palette[Palette.TextRoles[props.Role]] else WHITE,
			ImageTransparency = props.Transparency,
			LayoutOrder = props.LayoutOrder,
			Position = props.Position,
			Rotation = props.Rotation,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(props.Size, props.Size),
		})
	end)
end

return Icon
