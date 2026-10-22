local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)

local Icon = require(script.Parent.Icon)
local Motion = require(script.Parent.Parent.Parent.Motion)
local Palette = require(script.Parent.Parent.Parent.Palette)
local PluginContext = require(script.Parent.Parent.Parent.Parent.PluginContext)
local Text = require(script.Parent.Text)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local ErrorBlock = Roact.Component:extend("ErrorBlock")

ErrorBlock.defaultProps = { Text = "", Size = 11, Settled = false, LayoutOrder = 0 }

function ErrorBlock:init()
	self.revealMotor = Flipper.SingleMotor.new(if self.props.Settled then 1 else 0)
	self.reveal = RoactFlipper.getBinding(self.revealMotor)
end

--[[
	Fades in as the error arrives; `Settled` starts it shown, for a closing copy that was already showing it.
]]
function ErrorBlock:didMount()
	if not self.props.Settled then
		self.revealMotor:setGoal(Motion:Goal(1, "fade"))
	end
end

function ErrorBlock:willUnmount()
	self.revealMotor:destroy()
end

--[[
	An error in Studio's error colour beside the error icon, on a block washed with the same colour, so colour is
		never the only sign that something went wrong.
]]
function ErrorBlock:render()
	local props = self.props
	local transparency = self.reveal:map(function(value)
		return 1 - value
	end)

	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = palette.error,
			BackgroundTransparency = self.reveal:map(function(value)
				return 1 - (1 - Palette.WashTransparency) * value
			end),
			BorderSizePixel = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(1, 0),
		}, {
			Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Padding = Roact.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 7),
				PaddingRight = UDim.new(0, 7),
				PaddingTop = UDim.new(0, 5),
			}),
			Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			Icon = Roact.createElement(Icon, {
				Image = PluginContext.PluginSettings.Icons.Error,
				Size = 14,
				Tinted = false,
				Transparency = transparency,
				LayoutOrder = 1,
			}),
			Message = Roact.createElement(Text, {
				Text = props.Text,
				Role = "error",
				Size = props.Size,
				Wrap = true,
				Width = UDim.new(1, -20),
				Transparency = transparency,
				LayoutOrder = 2,
			}),
		})
	end)
end

return ErrorBlock
