local Flipper = require(script.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Packages.RoactFlipper)
local Sift = require(script.Parent.Parent.Parent.Packages.Sift)

local Icon = require(script.Parent.Common.Icon)
local IconButton = require(script.Parent.Common.IconButton)
local Motion = require(script.Parent.Parent.Motion)
local OverlayContext = require(script.Parent.Parent.OverlayContext)
local PluginContext = require(script.Parent.Parent.Parent.PluginContext)
local Spinner = require(script.Parent.Common.Spinner)
local Text = require(script.Parent.Common.Text)

local withPalette = require(script.Parent.Parent.withPalette)

local ROW_HEIGHT = 26
local VISIBLE_ROWS = 6

local VersionSelect = Roact.Component:extend("VersionSelect")

VersionSelect.defaultProps = {
	Versions = {},
	Open = false,
	Loading = false,
	Disabled = false,
	LayoutOrder = 0,
	OnSelected = function() end,
}

--[[
	Whether the list is open: asked for, and not waiting for versions or switched off.
]]
local function isOpen(props, state): boolean
	return state.open and not props.Loading and not props.Disabled
end

function VersionSelect:init()
	self.revealMotor = Flipper.SingleMotor.new(if self.props.Open then 1 else 0)
	self.reveal = RoactFlipper.getBinding(self.revealMotor)
	self:setState({ open = self.props.Open, showing = self.props.Open })
end

function VersionSelect:didMount()
	self.revealMotor:onComplete(function()
		if not isOpen(self.props, self.state) then
			self:setState({ showing = false })
		end
	end)
end

--[[
	Unfolds the list when it opens and folds it away when it closes, keeping it mounted until it has.
]]
function VersionSelect:didUpdate(previous, previousState)
	local was = isOpen(previous, previousState)
	local open = isOpen(self.props, self.state)

	if open == was then
		return
	end

	if open then
		self:setState({ showing = true })
	end

	self.revealMotor:setGoal(Motion:Goal(if open then 1 else 0, "expand"))
end

function VersionSelect:willUnmount()
	self.revealMotor:destroy()
end

--[[
	One version in the open list, tagged installed, latest or prerelease.
]]
function VersionSelect:renderOption(palette, version: string, order: number)
	local props = self.props
	local chosen = version == props.Value
	local tag = if version == props.Installed
		then "installed"
		elseif version == props.Latest then "latest"
		elseif string.find(version, "-", 1, true) then "prerelease"
		else nil

	return Roact.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = palette.rowHover,
		BackgroundTransparency = if chosen then 0 else 1,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Text = "",
		[Roact.Event.Activated] = function()
			self:setState({ open = false })
			props.OnSelected(version)
		end,
	}, {
		Padding = Roact.createElement("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Number = Roact.createElement(Text, {
			Text = version,
			Role = if chosen then "strong" else "text",
			Size = 12,
			Mono = true,
			Flex = true,
			LayoutOrder = 1,
		}),
		Tag = if tag
			then Roact.createElement(Text, {
				Text = tag,
				Role = if tag == "latest" or tag == "installed" then "accent" else "dim",
				Size = 11,
				Hug = true,
				LayoutOrder = 2,
			})
			else nil,
	})
end

--[[
	The list floating over a short surface: a heading with a close button over the versions, filling the surface and
		rising from its bottom edge. It is a button so its own background takes the clicks meant for it, never the
		fields under it.
]]
function VersionSelect:renderPicker(palette, options)
	return Roact.createElement("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = palette.surface,
		BorderSizePixel = 0,
		Position = self.reveal:map(function(value)
			return UDim2.fromScale(0, 1 - value)
		end),
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, {
		Padding = Roact.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 8),
		}),
		Layout = Roact.createElement(
			"UIListLayout",
			{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Head = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 18),
		}, {
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Title = Roact.createElement(Text, {
				Text = "Choose a version",
				Role = "sub",
				Size = 12,
				Weight = Enum.FontWeight.Medium,
				Flex = true,
				LayoutOrder = 1,
			}),
			Close = Roact.createElement(IconButton, {
				Image = PluginContext.PluginSettings.Icons.Close,
				Size = 14,
				LayoutOrder = 2,
				OnActivated = function()
					self:setState({ open = false })
				end,
			}),
		}),
		List = Roact.createElement(
			"ScrollingFrame",
			{
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = palette.field,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				LayoutOrder = 2,
				ScrollBarImageColor3 = palette.dimText,
				ScrollBarThickness = 4,
				Size = UDim2.fromScale(1, 0),
			},
			Sift.Dictionary.merge(options, {
				Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
			})
		),
	})
end

--[[
	The version picker: the chosen version with its tag, opening into a list newest first. It opens in place, so it
		never floats outside a surface that clips; a surface too short for that offers room through `OverlayContext`,
		and the list floats over the whole surface there instead.
]]
function VersionSelect:render()
	return Roact.createElement(OverlayContext.Consumer, {
		render = function(overlay)
			return withPalette(function(palette)
				return self:renderSelect(palette, overlay)
			end)
		end,
	})
end

--[[
	The select and its list, in place or floating over `overlay` when a surface offers one.
]]
function VersionSelect:renderSelect(palette, overlay)
	local props = self.props
	local open = isOpen(props, self.state)
	local visible = math.min(#props.Versions, VISIBLE_ROWS)
	local options = {
		Layout = Roact.createElement("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}

	for index, version in props.Versions do
		options[`Version {version}`] = self:renderOption(palette, version, index)
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
		Select = Roact.createElement("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = palette.field,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Text = "",
			[Roact.Event.Activated] = function()
				if not props.Loading and not props.Disabled then
					self:setState({ open = not self.state.open })
				end
			end,
		}, {
			Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 5) }),
			Stroke = Roact.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = if open then palette.accent else palette.fieldBorder,
			}),
			Padding = Roact.createElement(
				"UIPadding",
				{ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) }
			),
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Spinner = if props.Loading then Roact.createElement(Spinner, { Size = 12, LayoutOrder = 1 }) else nil,
			Value = Roact.createElement(Text, {
				Text = if props.Loading then "Reading versions" else props.Value or "No version",
				Role = if props.Loading or props.Disabled then "dim" else "strong",
				Size = 12,
				Weight = Enum.FontWeight.Medium,
				Mono = not props.Loading,
				Hug = true,
				LayoutOrder = 2,
			}),
			Tag = if not props.Loading
					and props.Value
					and props.Value == props.Latest
				then Roact.createElement(
					Text,
					{ Text = "latest", Role = "accent", Size = 11, Hug = true, LayoutOrder = 3 }
				)
				else nil,
			Spacer = Roact.createElement(
				"Frame",
				{ BackgroundTransparency = 1, LayoutOrder = 4, Size = UDim2.new() },
				{
					Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
				}
			),
			Chevron = Roact.createElement(Icon, {
				Image = if open
					then PluginContext.PluginSettings.Icons.ChevronUp
					else PluginContext.PluginSettings.Icons.ChevronDown,
				Size = 14,
				LayoutOrder = 5,
			}),
		}),
		Picker = if self.state.showing and overlay
			then Roact.createElement(Roact.Portal, { target = overlay }, {
				["Version picker"] = self:renderPicker(palette, options),
			})
			else nil,
		Options = if self.state.showing and not overlay
			then Roact.createElement("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = palette.field,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				LayoutOrder = 2,
				ScrollBarImageColor3 = palette.dimText,
				ScrollBarThickness = 4,
				Size = self.reveal:map(function(value)
					return UDim2.new(1, 0, 0, visible * ROW_HEIGHT * value)
				end),
			}, options)
			else nil,
	})
end

return VersionSelect
