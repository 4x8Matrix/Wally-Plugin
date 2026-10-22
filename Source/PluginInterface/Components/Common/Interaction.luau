local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)

local Motion = require(script.Parent.Parent.Parent.Motion)

local Interaction = Roact.Component:extend("Interaction")

Interaction.defaultProps = { Disabled = false }

function Interaction:init()
	self.hoverMotor = Flipper.SingleMotor.new(0)
	self.pressMotor = Flipper.SingleMotor.new(0)
	self.hover = RoactFlipper.getBinding(self.hoverMotor)
	self.press = RoactFlipper.getBinding(self.pressMotor)
	self.events = {
		[Roact.Event.MouseEnter] = function()
			self.hoverMotor:setGoal(Motion:Goal(1, "hover"))
		end,
		[Roact.Event.MouseLeave] = function()
			self.hoverMotor:setGoal(Motion:Goal(0, "hover"))
			self.pressMotor:setGoal(Motion:Goal(0, "press"))
		end,
		[Roact.Event.MouseButton1Down] = function()
			if not self.props.Disabled then
				self.pressMotor:setGoal(Motion:Goal(1, "press"))
			end
		end,
		[Roact.Event.MouseButton1Up] = function()
			self.pressMotor:setGoal(Motion:Goal(0, "press"))
		end,
	}
end

function Interaction:willUnmount()
	self.hoverMotor:destroy()
	self.pressMotor:destroy()
end

--[[
	Hover and press as springs for any control: `render(hover, press, events)` gets both as bindings from 0 to 1 and
		the mouse events to put on the control's button, so a highlight fades instead of snapping and a press can
		shrink the control and spring it back. A disabled control fades its hover but never presses.
]]
function Interaction:render()
	return self.props.render(self.hover, self.press, self.events)
end

return Interaction
