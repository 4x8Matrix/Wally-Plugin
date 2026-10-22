local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local Sift = require(script.Parent.Parent.Parent.Packages.Sift)

local Divider = require(script.Parent.Common.Divider)
local Interaction = require(script.Parent.Common.Interaction)
local Text = require(script.Parent.Common.Text)

local withPalette = require(script.Parent.Parent.withPalette)

local InstalledRow = Roact.Component:extend("InstalledRow")

InstalledRow.defaultProps = { Selected = false, LayoutOrder = 0, OnActivated = function() end }

--[[
	One installed package: its name in Packages over its package id, and the resolved version over the requirement
		the place asks for.
]]
function InstalledRow:render()
	local props = self.props
	local package = props.Package

	return Roact.createElement(Interaction, {
		render = function(hover, _, events)
			return withPalette(function(palette)
				return self:renderRow(palette, hover, events)
			end)
		end,
	})
end

--[[
	The row, with its hover fading in and out through the binding `Interaction` hands over.
]]
function InstalledRow:renderRow(palette, hover, events)
	local props = self.props
	local package = props.Package

	return Roact.createElement(
		"TextButton",
		Sift.Dictionary.merge({
			AutoButtonColor = false,
			BackgroundColor3 = palette.rowHover,
			BackgroundTransparency = if props.Selected
				then 0
				else hover:map(function(value)
					return 1 - value
				end),
			BorderSizePixel = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.new(1, 0, 0, 46),
			Text = "",
			[Roact.Event.Activated] = function()
				props.OnActivated(package)
			end,
		}, events),
		{
			Content = Roact.createElement("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
				Padding = Roact.createElement(
					"UIPadding",
					{ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }
				),
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Names = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.new(),
				}, {
					Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
					Layout = Roact.createElement(
						"UIListLayout",
						{ Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }
					),
					Alias = Roact.createElement(
						Text,
						{ Text = package.alias, Role = "strong", Weight = Enum.FontWeight.SemiBold, LayoutOrder = 1 }
					),
					Id = Roact.createElement(Text, {
						Text = `{package.scope}/{package.name}`,
						Role = "sub",
						Size = 11,
						Mono = true,
						LayoutOrder = 2,
					}),
				}),
				Versions = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.new(),
				}, {
					Layout = Roact.createElement("UIListLayout", {
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						Padding = UDim.new(0, 1),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Version = Roact.createElement(Text, {
						Text = package.version,
						Role = "strong",
						Size = 12,
						Weight = Enum.FontWeight.Medium,
						Mono = true,
						Hug = true,
						LayoutOrder = 1,
					}),
					Requirement = Roact.createElement(Text, {
						Text = package.requirement,
						Role = "dim",
						Size = 11,
						Mono = true,
						Hug = true,
						LayoutOrder = 2,
					}),
				}),
			}),
			Underline = Roact.createElement(
				"Frame",
				{ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) },
				{
					Line = Roact.createElement(Divider),
				}
			),
			["Selection bar"] = if props.Selected
				then Roact.createElement(
					"Frame",
					{ BackgroundColor3 = palette.accent, BorderSizePixel = 0, Size = UDim2.new(0, 2, 1, 0) }
				)
				else nil,
		}
	)
end

return InstalledRow
