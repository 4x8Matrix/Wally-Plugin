local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)

local Icon = require(script.Parent.Icon)
local Interaction = require(script.Parent.Interaction)
local Motion = require(script.Parent.Parent.Parent.Motion)
local PluginContext = require(script.Parent.Parent.Parent.Parent.PluginContext)
local Text = require(script.Parent.Text)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local TextField = Roact.Component:extend("TextField")

TextField.defaultProps = {
	Text = "",
	Placeholder = "",
	Hint = "",
	Mono = false,
	Error = false,
	ReadOnly = false,
	Height = 30,
	LayoutOrder = 0,
	OnChanged = function() end,
	OnSubmitted = function() end,
}

function TextField:init()
	self.focusMotor = Flipper.SingleMotor.new(0)
	self.focus = RoactFlipper.getBinding(self.focusMotor)
end

function TextField:willUnmount()
	self.focusMotor:destroy()
end

--[[
	A one-line input in Studio's field colours with an optional leading icon and trailing hint. Hovering eases it to the
		hover colour and focus eases its outline into the accent; an error outlines it in the error colour.
]]
function TextField:render()
	local props = self.props
	local family = if props.Mono
		then PluginContext.PluginSettings.Fonts.Mono
		else PluginContext.PluginSettings.Fonts.Sans

	return Roact.createElement(Interaction, {
		render = function(hover, _, events)
			return withPalette(function(palette)
				return self:renderField(palette, hover, events, family)
			end)
		end,
	})
end

--[[
	The field itself, with the hover binding and the mouse events `Interaction` hands over.
]]
function TextField:renderField(palette, hover, events, family: string)
	local props = self.props

	return Roact.createElement("Frame", {
		BackgroundColor3 = hover:map(function(value)
			return if value <= 0 then palette.field else palette.field:Lerp(palette.fieldHover, value)
		end),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, props.Height),
		[Roact.Event.MouseEnter] = events[Roact.Event.MouseEnter],
		[Roact.Event.MouseLeave] = events[Roact.Event.MouseLeave],
	}, {
		Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 5) }),
		Stroke = Roact.createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = if props.Error
				then palette.error
				else self.focus:map(function(value)
					return if value <= 0
						then palette.fieldBorder
						elseif value >= 1 then palette.accent
						else palette.fieldBorder:Lerp(palette.accent, value)
				end),
		}),
		Padding = Roact.createElement("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Icon = if props.Icon
			then Roact.createElement(Icon, { Image = props.Icon, Size = 14, LayoutOrder = 1 })
			else nil,
		Input = Roact.createElement("TextBox", {
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			FontFace = Font.new(family, Enum.FontWeight.Regular),
			LayoutOrder = 2,
			PlaceholderColor3 = palette.dimText,
			PlaceholderText = props.Placeholder,
			Size = UDim2.fromScale(0, 1),
			Text = props.Text,
			TextColor3 = if props.ReadOnly then palette.subText else palette.strongText,
			TextEditable = not props.ReadOnly,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			[Roact.Change.Text] = function(input)
				if input.Text ~= props.Text then
					props.OnChanged(input.Text)
				end
			end,
			[Roact.Event.Focused] = function()
				self.focusMotor:setGoal(Motion:Goal(1, "hover"))
			end,
			[Roact.Event.FocusLost] = function(input, enterPressed)
				self.focusMotor:setGoal(Motion:Goal(0, "hover"))

				if enterPressed then
					props.OnSubmitted(input.Text)
				end
			end,
		}, {
			Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		}),
		Hint = if props.Hint ~= ""
			then Roact.createElement(Text, { Text = props.Hint, Role = "dim", Size = 11, Hug = true, LayoutOrder = 3 })
			else nil,
	})
end

return TextField
