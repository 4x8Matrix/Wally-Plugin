local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local Sift = require(script.Parent.Parent.Parent.Parent.Packages.Sift)

local Interaction = require(script.Parent.Interaction)
local Palette = require(script.Parent.Parent.Parent.Palette)
local PluginContext = require(script.Parent.Parent.Parent.Parent.PluginContext)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local Link = Roact.Component:extend("Link")

Link.defaultProps = {
	Text = "",
	Role = "accent",
	Size = 12,
	Disabled = false,
	LayoutOrder = 0,
	OnActivated = function() end,
}

--[[
	A secondary action written as text: Retry, Undo, Show in Explorer, Remove. Its underline fades in while hovered.
]]
function Link:render()
	local props = self.props

	return Roact.createElement(Interaction, {
		Disabled = props.Disabled,
		render = function(hover, _, events)
			return withPalette(function(palette)
				local colour = palette[Palette.TextRoles[if props.Disabled then "dim" else props.Role]]

				return Roact.createElement(
					"TextButton",
					Sift.Dictionary.merge({
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						FontFace = Font.new(PluginContext.PluginSettings.Fonts.Sans, Enum.FontWeight.Medium),
						LayoutOrder = props.LayoutOrder,
						Size = UDim2.fromOffset(0, math.ceil(props.Size * 1.3)),
						Text = props.Text,
						TextColor3 = colour,
						TextSize = props.Size,
						[Roact.Event.Activated] = function()
							if not props.Disabled then
								props.OnActivated()
							end
						end,
					}, events),
					{
						Underline = Roact.createElement("Frame", {
							AnchorPoint = Vector2.new(0, 1),
							BackgroundColor3 = colour,
							BackgroundTransparency = if props.Disabled
								then 1
								else hover:map(function(value)
									return 1 - value
								end),
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.new(1, 0, 0, 1),
						}),
					}
				)
			end)
		end,
	})
end

return Link
