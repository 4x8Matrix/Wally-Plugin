local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local Sift = require(script.Parent.Parent.Parent.Packages.Sift)

local Interaction = require(script.Parent.Common.Interaction)
local Text = require(script.Parent.Common.Text)

local withPalette = require(script.Parent.Parent.withPalette)

local REALMS = {
	{ realm = "shared", label = "Shared", place = "in ReplicatedStorage" },
	{ realm = "server", label = "Server", place = "in ServerStorage" },
}

local RealmSwitch = Roact.Component:extend("RealmSwitch")

RealmSwitch.defaultProps = {
	Value = "shared",
	ServerOnly = false,
	Locked = false,
	Caption = true,
	LayoutOrder = 0,
	OnChanged = function() end,
}

--[[
	Shared or Server, with the service the package goes into underneath. Shared is off for a server-only package, and
		an installed package's realm cannot be changed here. An unchosen segment that can be chosen lights up faintly
		on hover.
]]
function RealmSwitch:render()
	local props = self.props

	return withPalette(function(palette)
		local segments = {
			Padding = Roact.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, 2),
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 2),
				PaddingTop = UDim.new(0, 2),
			}),
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		local caption = ""

		for index, option in REALMS do
			local chosen = props.Value == option.realm
			local enabled = not props.Locked and not (option.realm == "shared" and props.ServerOnly)

			if chosen then
				caption = option.place
			end

			segments[`Realm {option.label}`] = Roact.createElement(Interaction, {
				Disabled = not enabled,
				render = function(hover, _, events)
					return Roact.createElement(
						"TextButton",
						Sift.Dictionary.merge({
							Active = enabled,
							AutoButtonColor = false,
							BackgroundColor3 = palette.field,
							BackgroundTransparency = if chosen
								then 0
								elseif enabled then hover:map(function(value)
									return 1 - 0.5 * value
								end)
								else 1,
							BorderSizePixel = 0,
							LayoutOrder = index,
							Size = UDim2.fromScale(0, 1),
							Text = "",
							[Roact.Event.Activated] = function()
								if enabled and not chosen then
									props.OnChanged(option.realm)
								end
							end,
						}, events),
						{
							Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
							Stroke = if chosen
								then Roact.createElement(
									"UIStroke",
									{ ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = palette.fieldBorder }
								)
								else nil,
							Label = Roact.createElement(Text, {
								Text = option.label,
								Role = if chosen then "strong" elseif enabled then "sub" else "dim",
								Size = 12,
								Weight = if chosen then Enum.FontWeight.SemiBold else Enum.FontWeight.Regular,
								XAlignment = Enum.TextXAlignment.Center,
								AnchorPoint = Vector2.new(0, 0.5),
								Position = UDim2.fromScale(0, 0.5),
							}),
						}
					)
				end,
			})
		end

		return Roact.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(1, 0),
		}, {
			Layout = Roact.createElement(
				"UIListLayout",
				{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
			),
			Track = Roact.createElement("Frame", {
				BackgroundColor3 = palette.track,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 30),
			}, {
				Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 5) }),
				Segments = Roact.createElement(
					"Frame",
					{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) },
					segments
				),
			}),
			Caption = if props.Caption
				then Roact.createElement(
					Text,
					{ Text = caption, Role = "dim", Size = 10, Mono = true, LayoutOrder = 2 }
				)
				else nil,
		})
	end)
end

return RealmSwitch
