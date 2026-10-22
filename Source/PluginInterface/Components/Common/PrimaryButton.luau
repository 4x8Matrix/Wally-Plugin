local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)
local Sift = require(script.Parent.Parent.Parent.Parent.Packages.Sift)

local Interaction = require(script.Parent.Interaction)
local Motion = require(script.Parent.Parent.Parent.Motion)
local Text = require(script.Parent.Text)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local PrimaryButton = Roact.Component:extend("PrimaryButton")

PrimaryButton.defaultProps = {
	Text = "",
	Disabled = false,
	Height = 36,
	LayoutOrder = 0,
	OnActivated = function() end,
}

function PrimaryButton:init()
	self.progressMotor = Flipper.SingleMotor.new(self.props.Progress or 0)
	self.progress = RoactFlipper.getBinding(self.progressMotor)
	self.enabledMotor = Flipper.SingleMotor.new(if self.props.Disabled then 0 else 1)
	self.enabled = RoactFlipper.getBinding(self.enabledMotor)
end

--[[
	Moves the progress fill to the new progress, and crossfades between the accent and the greyed-out look when the
		button is enabled or disabled.
]]
function PrimaryButton:didUpdate(previous)
	if self.props.Progress ~= previous.Progress then
		self.progressMotor:setGoal(Motion:Goal(self.props.Progress or 0, "progress"))
	end

	if self.props.Disabled ~= previous.Disabled then
		self.enabledMotor:setGoal(Motion:Goal(if self.props.Disabled then 0 else 1, "fade"))
	end
end

function PrimaryButton:willUnmount()
	self.progressMotor:destroy()
	self.enabledMotor:destroy()
end

--[[
	The one accent action on a surface. With `Progress` it becomes its own progress bar and ignores clicks; disabled,
		it greys out and says why in its label. Hovering lightens it and pressing shrinks it a little, both on springs.
		The press scales a face inside a frame of fixed size, so what is laid out around the button never moves.
]]
function PrimaryButton:render()
	local props = self.props
	local busy = if props.Progress then true else false

	return Roact.createElement(Interaction, {
		Disabled = props.Disabled or busy,
		render = function(hover, press, events)
			return withPalette(function(palette)
				return Roact.createElement("Frame", {
					BackgroundTransparency = 1,
					LayoutOrder = props.LayoutOrder,
					Size = UDim2.new(1, 0, 0, props.Height),
				}, {
					Face = Roact.createElement(
						"TextButton",
						Sift.Dictionary.merge({
							AnchorPoint = Vector2.new(0.5, 0.5),
							AutoButtonColor = false,
							BackgroundColor3 = self.enabled:map(function(value)
								return if value >= 1
									then palette.accent
									elseif value <= 0 then palette.track
									else palette.track:Lerp(palette.accent, value)
							end),
							BackgroundTransparency = if busy
								then 0.75
								else Roact.joinBindings({ hover, self.enabled }):map(function(values)
									return 0.12 * values[1] * values[2]
								end),
							BorderSizePixel = 0,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(1, 1),
							Text = "",
							[Roact.Event.Activated] = function()
								if not props.Disabled and not busy then
									props.OnActivated()
								end
							end,
						}, events),
						{
							Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
							Press = Roact.createElement("UIScale", {
								Scale = press:map(function(value)
									return 1 - 0.03 * value
								end),
							}),
							Stroke = Roact.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = palette.fieldBorder,
								Transparency = self.enabled,
							}),
							Fill = Roact.createElement("Frame", {
								BackgroundColor3 = palette.accent,
								BorderSizePixel = 0,
								Size = self.progress:map(function(value)
									return UDim2.fromScale(value, 1)
								end),
								Visible = busy,
							}, {
								Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
							}),
							Label = Roact.createElement(Text, {
								Text = props.Text,
								Role = if props.Disabled then "dim" elseif busy then "strong" else "onAccent",
								Size = 13,
								Weight = Enum.FontWeight.SemiBold,
								XAlignment = Enum.TextXAlignment.Center,
								AnchorPoint = Vector2.new(0, 0.5),
								Position = UDim2.fromScale(0, 0.5),
								ZIndex = 2,
							}),
						}
					),
				})
			end)
		end,
	})
end

return PrimaryButton
