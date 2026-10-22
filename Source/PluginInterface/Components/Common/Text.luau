local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)

local Palette = require(script.Parent.Parent.Parent.Palette)
local PluginContext = require(script.Parent.Parent.Parent.Parent.PluginContext)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local Text = Roact.Component:extend("Text")

Text.defaultProps = {
	Text = "",
	Role = "text",
	Size = 13,
	Weight = Enum.FontWeight.Regular,
	Mono = false,
	Wrap = false,
	Hug = false,
	Flex = false,
	Height = 0,
	XAlignment = Enum.TextXAlignment.Left,
	Width = UDim.new(1, 0),
	Position = UDim2.new(),
	AnchorPoint = Vector2.zero,
	Transparency = 0,
	ZIndex = 1,
	LayoutOrder = 0,
}

--[[
	A label in Builder Sans, or Builder Mono for ids and versions, coloured by its role. It truncates on one line
		unless it wraps or hugs its text; with `Flex` it takes the room its row has left, and a `Height` fixes it.
]]
function Text:render()
	local props = self.props
	local lineHeight = math.ceil(props.Size * 1.3)
	local family = if props.Mono
		then PluginContext.PluginSettings.Fonts.Mono
		else PluginContext.PluginSettings.Fonts.Sans
	local size = if props.Height > 0
		then UDim2.new(props.Width, UDim.new(0, props.Height))
		elseif props.Hug or props.Flex then UDim2.fromOffset(0, lineHeight)
		elseif props.Wrap then UDim2.new(props.Width, UDim.new(0, 0))
		else UDim2.new(props.Width, UDim.new(0, lineHeight))

	return withPalette(function(palette)
		return Roact.createElement("TextLabel", {
			AnchorPoint = props.AnchorPoint,
			AutomaticSize = if props.Height > 0
				then Enum.AutomaticSize.None
				elseif props.Wrap then Enum.AutomaticSize.Y
				elseif props.Hug then Enum.AutomaticSize.X
				else Enum.AutomaticSize.None,
			BackgroundTransparency = 1,
			FontFace = Font.new(family, props.Weight),
			LayoutOrder = props.LayoutOrder,
			Position = props.Position,
			Size = size,
			Text = props.Text,
			TextColor3 = palette[Palette.TextRoles[props.Role]],
			TextSize = props.Size,
			TextTransparency = props.Transparency,
			TextTruncate = if props.Wrap or props.Hug then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
			TextWrapped = props.Wrap,
			TextXAlignment = props.XAlignment,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = props.ZIndex,
		}, {
			Flex = if props.Flex then Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) else nil,
		})
	end)
end

return Text
