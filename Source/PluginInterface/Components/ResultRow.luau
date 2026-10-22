local Flipper = require(script.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Packages.RoactFlipper)
local Sift = require(script.Parent.Parent.Parent.Packages.Sift)

local Divider = require(script.Parent.Common.Divider)
local Interaction = require(script.Parent.Common.Interaction)
local Motion = require(script.Parent.Parent.Motion)
local Text = require(script.Parent.Common.Text)

local withPalette = require(script.Parent.Parent.withPalette)

local ResultRow = Roact.Component:extend("ResultRow")

ResultRow.defaultProps =
	{ WidthClass = "s", Selected = false, Strip = false, LayoutOrder = 0, OnActivated = function() end }

function ResultRow:init()
	self.revealMotor = Flipper.SingleMotor.new(if self.props.Delay then 0 else 1)
	self.reveal = RoactFlipper.getBinding(self.revealMotor)
end

--[[
	Fades the row's text in after `Delay`, so a new set of results arrives one row after another. Without a delay, or
		with reduced motion, the row is simply there.
]]
function ResultRow:revealIn(restart: boolean)
	local delay = self.props.Delay

	if self.revealThread then
		task.cancel(self.revealThread)
	end

	if not delay or Motion:ReadReduced() then
		self.revealMotor:setGoal(Flipper.Instant.new(1))

		return
	end

	if restart then
		Motion:Snap(self.revealMotor, 0)
	end

	self.revealThread = task.delay(delay, function()
		self.revealThread = nil
		self.revealMotor:setGoal(Motion:Goal(1, "fade"))
	end)
end

function ResultRow:didMount()
	self:revealIn(false)
end

--[[
	Fades in again when the list shows a new set of results.
]]
function ResultRow:didUpdate(previous)
	if self.props.Generation ~= previous.Generation then
		self:revealIn(true)
	end
end

function ResultRow:willUnmount()
	if self.revealThread then
		task.cancel(self.revealThread)
	end

	self.revealMotor:destroy()
end

--[[
	The row's text for its width class: name, scope and version on one line when tiny; a second line with the
		description when narrow; Package, Description and Latest columns when wide. `rise` lowers the text as it fades
		in: rows of fixed height move their content, and rows that size themselves trade top padding for bottom, so a
		row never changes height while it rises.
]]
function ResultRow:renderContent(transparency, rise)
	local props = self.props
	local result = props.Result
	local layout = function(direction, gap)
		return Roact.createElement("UIListLayout", {
			FillDirection = direction,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
	end

	if props.WidthClass == "l" then
		return Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = rise:map(function(offset)
				return UDim2.fromOffset(0, offset)
			end),
			Size = UDim2.fromScale(1, 1),
		}, {
			Padding = Roact.createElement(
				"UIPadding",
				{ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }
			),
			Layout = layout(Enum.FillDirection.Horizontal, 14),
			Names = Roact.createElement(
				"Frame",
				{ BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(0, 210, 1, 0) },
				{
					Layout = layout(Enum.FillDirection.Horizontal, 6),
					Name = Roact.createElement(Text, {
						Text = result.name,
						Role = "strong",
						Transparency = transparency,
						Weight = Enum.FontWeight.SemiBold,
						Hug = true,
						LayoutOrder = 1,
					}),
					Scope = Roact.createElement(Text, {
						Text = result.scope,
						Role = "sub",
						Transparency = transparency,
						Size = 12,
						Flex = true,
						LayoutOrder = 2,
					}),
				}
			),
			Description = Roact.createElement(Text, {
				Text = result.description,
				Role = "sub",
				Transparency = transparency,
				Size = 12,
				Flex = true,
				LayoutOrder = 2,
			}),
			Version = Roact.createElement(Text, {
				Text = result.version,
				Role = "dim",
				Transparency = transparency,
				Size = 11,
				Mono = true,
				Width = UDim.new(0, 52),
				XAlignment = Enum.TextXAlignment.Right,
				LayoutOrder = 3,
			}),
		})
	end

	local top = {
		Layout = layout(Enum.FillDirection.Horizontal, if props.WidthClass == "xs" then 5 else 6),
		Name = Roact.createElement(Text, {
			Text = result.name,
			Role = "strong",
			Transparency = transparency,
			Size = if props.WidthClass == "xs" then 13 else 14,
			Weight = Enum.FontWeight.SemiBold,
			Hug = true,
			LayoutOrder = 1,
		}),
		Scope = Roact.createElement(Text, {
			Text = result.scope,
			Role = "sub",
			Transparency = transparency,
			Size = if props.WidthClass == "xs" then 11 else 12,
			Flex = true,
			LayoutOrder = 2,
		}),
		Version = Roact.createElement(Text, {
			Text = result.version,
			Role = "dim",
			Transparency = transparency,
			Size = if props.WidthClass == "xs" then 10.5 else 11,
			Mono = true,
			Hug = true,
			LayoutOrder = 3,
		}),
	}

	if props.WidthClass == "xs" then
		return Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = rise:map(function(offset)
				return UDim2.fromOffset(0, offset)
			end),
			Size = UDim2.fromScale(1, 1),
		}, {
			Padding = Roact.createElement(
				"UIPadding",
				{ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }
			),
			Line = Roact.createElement("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, top),
		})
	end

	return Roact.createElement(
		"Frame",
		{ AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0) },
		{
			Padding = Roact.createElement("UIPadding", {
				PaddingBottom = rise:map(function(offset)
					return UDim.new(0, 9 - offset)
				end),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				PaddingTop = rise:map(function(offset)
					return UDim.new(0, 9 + offset)
				end),
			}),
			Layout = layout(Enum.FillDirection.Vertical, 2),
			Top = Roact.createElement(
				"Frame",
				{ BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 19) },
				top
			),
			Description = Roact.createElement(
				Text,
				{ Text = result.description, Role = "sub", Transparency = transparency, Size = 12, LayoutOrder = 2 }
			),
		}
	)
end

--[[
	One registry result. Hover and selection both use Studio's item hover colour, the hover fading in and out; the
		selected row also carries an accent bar on its left edge.
]]
function ResultRow:render()
	local props = self.props
	local height = if props.WidthClass == "l"
		then (if props.Strip then 32 else 40)
		elseif props.WidthClass == "xs" then 34
		else 0
	local transparency = self.reveal:map(function(value)
		return 1 - value
	end)
	local rise = self.reveal:map(function(value)
		return math.round((1 - value) * 6)
	end)

	return Roact.createElement(Interaction, {
		render = function(hover, _, events)
			return withPalette(function(palette)
				return Roact.createElement(
					"TextButton",
					Sift.Dictionary.merge({
						AutoButtonColor = false,
						AutomaticSize = if height == 0 then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
						BackgroundColor3 = palette.rowHover,
						BackgroundTransparency = if props.Selected
							then 0
							else hover:map(function(value)
								return 1 - value
							end),
						BorderSizePixel = 0,
						LayoutOrder = props.LayoutOrder,
						Size = UDim2.new(1, 0, 0, height),
						Text = "",
						[Roact.Event.Activated] = function()
							props.OnActivated(props.Result)
						end,
					}, events),
					{
						Content = self:renderContent(transparency, rise),
						Underline = Roact.createElement("Frame", {
							BackgroundTransparency = 1,
							Position = UDim2.new(0, 0, 1, -1),
							Size = UDim2.new(1, 0, 0, 1),
						}, {
							Line = Roact.createElement(Divider),
						}),
						["Selection bar"] = if props.Selected
							then Roact.createElement("Frame", {
								BackgroundColor3 = palette.accent,
								BorderSizePixel = 0,
								Size = UDim2.new(0, 2, 1, 0),
							})
							else nil,
					}
				)
			end)
		end,
	})
end

return ResultRow
