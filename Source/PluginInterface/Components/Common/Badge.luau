local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)

local Motion = require(script.Parent.Parent.Parent.Motion)
local Text = require(script.Parent.Text)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local Badge = Roact.Component:extend("Badge")

Badge.defaultProps = { Text = "", Active = false, LayoutOrder = 0 }

function Badge:init()
	self.flashMotor = Flipper.SingleMotor.new(0)
	self.flash = RoactFlipper.getBinding(self.flashMotor)
end

--[[
	Flashes when the count changes, so a new install or removal is noticed. A flash of colour rather than a change of
		scale, because the tab holding the badge sizes itself to it and would grow and shrink with the pop; with
		reduced motion the count just changes.
]]
function Badge:didUpdate(previous)
	if self.props.Text ~= previous.Text and not Motion:ReadReduced() then
		Motion:Snap(self.flashMotor, 1)
		self.flashMotor:setGoal(Motion:Goal(0, "fade"))
	end
end

function Badge:willUnmount()
	self.flashMotor:destroy()
end

--[[
	A small count in a pill, in the accent when `Active`.
]]
function Badge:render()
	local props = self.props

	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = self.flash:map(function(value)
				local resting = if props.Active then palette.accent else palette.track
				local lit = if props.Active then palette.accent:Lerp(palette.accentText, 0.45) else palette.accent

				return if value <= 0 then resting else resting:Lerp(lit, value)
			end),
			BorderSizePixel = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromOffset(0, 16),
		}, {
			Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Padding = Roact.createElement("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
			Layout = Roact.createElement("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Center }),
			Value = Roact.createElement(Text, {
				Text = props.Text,
				Role = if props.Active then "onAccent" else "sub",
				Size = 10,
				Weight = Enum.FontWeight.Medium,
				Mono = true,
				Hug = true,
			}),
		})
	end)
end

return Badge
