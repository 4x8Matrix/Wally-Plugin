local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)
local RoactRodux = require(script.Parent.Parent.Parent.Parent.Packages.RoactRodux)

local Motion = require(script.Parent.Parent.Parent.Motion)
local Shield = require(script.Parent.Shield)
local Spinner = require(script.Parent.Spinner)
local Text = require(script.Parent.Text)

local describeStep = require(script.Parent.Parent.Parent.Parent.PluginUtilities.describeStep)
local selectionKey = require(script.Parent.Parent.Parent.Parent.PluginUtilities.selectionKey)
local withPalette = require(script.Parent.Parent.Parent.withPalette)

local BusyOverlay = Roact.Component:extend("BusyOverlay")

BusyOverlay.defaultProps = { Compact = false, Settled = false, ZIndex = 10 }

--[[
	Whether the running operation is for what the surface shows.
]]
local function isBusy(store): boolean
	local operation = store.operation

	return if operation and operation.target == selectionKey(store.selection) then true else false
end

function BusyOverlay:init()
	self.fadeMotor = Flipper.SingleMotor.new(if self.props.Settled and isBusy(self.props.store) then 1 else 0)
	self.fade = RoactFlipper.getBinding(self.fadeMotor)
	self:setState({ shown = false })
end

--[[
	Keeps the spinner and the step mounted while the operation runs and while the overlay fades out after it, so the
		last step stays readable as it goes.
]]
function BusyOverlay.getDerivedStateFromProps(props)
	if isBusy(props.store) then
		return { shown = true, step = describeStep(props.store.operation) }
	end

	return
end

function BusyOverlay:didMount()
	self.fadeMotor:onComplete(function()
		if not isBusy(self.props.store) then
			self:setState({ shown = false })
		end
	end)

	if isBusy(self.props.store) and not self.props.Settled then
		self.fadeMotor:setGoal(Motion:Goal(1, "fade"))
	end
end

--[[
	Fades in when an operation starts for this surface and out when it ends.
]]
function BusyOverlay:didUpdate(previous)
	local was = isBusy(previous.store)
	local busy = isBusy(self.props.store)

	if was ~= busy then
		self.fadeMotor:setGoal(Motion:Goal(if busy then 1 else 0, "fade"))
	end
end

function BusyOverlay:willUnmount()
	self.fadeMotor:destroy()
end

--[[
	A wash in the surface's colour over the fields while an install, update or removal runs for them, with a spinner
		in the middle and the step it is on underneath, so the work in the background is plain to see. While busy it
		takes the clicks meant for the dimmed fields, and lets them through again as soon as the operation ends;
		everything outside the surface keeps working. `Compact` puts the spinner beside the step for a strip one line
		tall, and `Settled` starts it at rest, for a closing copy that was already showing it. A surface that sizes
		itself to its content passes `Height`, a binding of the measured height of what the wash covers, since a wash
		filling it would stretch it to the height of the widget.
]]
function BusyOverlay:render()
	local props = self.props
	local state = self.state
	local busy = isBusy(props.store)
	local transparency = self.fade:map(function(value)
		return 1 - value
	end)

	return withPalette(function(palette)
		return Roact.createFragment({
			Busy = Roact.createElement("Frame", {
				BackgroundColor3 = palette.surface,
				BackgroundTransparency = self.fade:map(function(value)
					return 1 - 0.8 * value
				end),
				BorderSizePixel = 0,
				Size = if props.Height
					then props.Height:map(function(height)
						return UDim2.new(1, 0, 0, height)
					end)
					else UDim2.fromScale(1, 1),
				Visible = self.fade:map(function(value)
					return value > 0.01
				end),
				ZIndex = props.ZIndex,
			}, {
				Catch = if busy then Roact.createElement(Shield) else nil,
				Content = if state.shown
					then Roact.createElement("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
					}, {
						Layout = Roact.createElement("UIListLayout", {
							FillDirection = if props.Compact
								then Enum.FillDirection.Horizontal
								else Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Spinner = Roact.createElement(Spinner, {
							Size = if props.Compact then 16 else 32,
							Transparency = transparency,
							LayoutOrder = 1,
						}),
						Step = Roact.createElement(Text, {
							Text = state.step or "",
							Role = "sub",
							Size = 12,
							Weight = Enum.FontWeight.Medium,
							Hug = true,
							Transparency = transparency,
							LayoutOrder = 2,
						}),
					})
					else nil,
			}),
		})
	end)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(BusyOverlay)
