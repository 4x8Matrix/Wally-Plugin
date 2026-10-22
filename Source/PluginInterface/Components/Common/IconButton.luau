local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local Sift = require(script.Parent.Parent.Parent.Parent.Packages.Sift)

local Interaction = require(script.Parent.Interaction)
local Palette = require(script.Parent.Parent.Parent.Palette)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local IconButton = Roact.Component:extend("IconButton")

IconButton.defaultProps = { Size = 16, Role = "sub", LayoutOrder = 0, OnActivated = function() end }

--[[
	A clickable icon, such as close or dismiss, tinted by its role: a little faint at rest and full on hover.
]]
function IconButton:render()
	local props = self.props

	return Roact.createElement(Interaction, {
		render = function(hover, _, events)
			return withPalette(function(palette)
				return Roact.createElement(
					"ImageButton",
					Sift.Dictionary.merge({
						BackgroundTransparency = 1,
						Image = props.Image,
						ImageColor3 = palette[Palette.TextRoles[props.Role]],
						ImageTransparency = hover:map(function(value)
							return 0.3 * (1 - value)
						end),
						LayoutOrder = props.LayoutOrder,
						Size = UDim2.fromOffset(props.Size, props.Size),
						[Roact.Event.Activated] = props.OnActivated,
					}, events)
				)
			end)
		end,
	})
end

return IconButton
