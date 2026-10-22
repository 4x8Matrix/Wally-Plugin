local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)
local RoactRodux = require(script.Parent.Parent.Parent.Parent.Packages.RoactRodux)

local BusyOverlay = require(script.Parent.Parent.Common.BusyOverlay)
local Divider = require(script.Parent.Parent.Common.Divider)
local FloatingLayer = require(script.Parent.Parent.Common.FloatingLayer)
local Icon = require(script.Parent.Parent.Common.Icon)
local InstallAction = require(script.Parent.Parent.InstallAction)
local InstallForm = require(script.Parent.Parent.InstallForm)
local InstallProblems = require(script.Parent.Parent.InstallProblems)
local Motion = require(script.Parent.Parent.Parent.Motion)
local PackageTitles = require(script.Parent.Parent.PackageTitles)
local PluginContext = require(script.Parent.Parent.Parent.Parent.PluginContext)
local ScrollBody = require(script.Parent.Parent.Common.ScrollBody)
local Shield = require(script.Parent.Parent.Common.Shield)
local Text = require(script.Parent.Parent.Common.Text)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local FullPanel = Roact.Component:extend("FullPanel")

FullPanel.defaultProps = { Width = 300, Closing = false, OnClosed = function() end, LayoutOrder = 0 }

function FullPanel:init()
	self.pushMotor = Flipper.SingleMotor.new(if self.props.Closing then 0 else 1)
	self.push = RoactFlipper.getBinding(self.pushMotor)
end

--[[
	Pushes in from the right edge as it mounts; a closing copy pushes back out and says when it is gone.
]]
function FullPanel:didMount()
	if self.props.Closing then
		self.pushMotor:onComplete(function()
			self.props.OnClosed()
		end)
		self.pushMotor:setGoal(Motion:Goal(1, "push"))
	else
		self.pushMotor:setGoal(Motion:Goal(0, "push"))
	end
end

function FullPanel:willUnmount()
	self.pushMotor:destroy()
end

--[[
	The install options in place of the list, for widgets too short or too narrow for a sheet. The action follows the
		last field while everything fits; past that the fields scroll and the action pins at the bottom. It lies over the
		list, so the list shows as a closing copy pushes away; a clear shield takes the copy's clicks. The panel is
		narrow or short, so the version list floats over all of it.
]]
function FullPanel:render()
	local props = self.props
	local store = props.store
	local tiny = props.Width < 260
	local gutter = if tiny then 10 else 14

	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			BackgroundColor3 = palette.background,
			BorderSizePixel = 0,
			LayoutOrder = props.LayoutOrder,
			Position = self.push:map(function(value)
				return UDim2.fromScale(value, 0)
			end),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			Shield = if props.Closing then Roact.createElement(Shield, { ZIndex = 10 }) else nil,
			Floating = Roact.createElement(FloatingLayer, {}, {
				Panel = Roact.createElement("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
					Layout = Roact.createElement("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
					Head = Roact.createElement("TextButton", {
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 34),
						Text = "",
						[Roact.Event.Activated] = store.onSelectionCleared,
					}, {
						Padding = Roact.createElement("UIPadding", { PaddingLeft = UDim.new(0, gutter - 2) }),
						Layout = Roact.createElement("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 4),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),
						Back = Roact.createElement(Icon, {
							Image = PluginContext.PluginSettings.Icons.ChevronLeft,
							Size = 16,
							LayoutOrder = 1,
						}),
						Label = Roact.createElement(Text, {
							Text = if tiny then "Results" else "Back to results",
							Role = "sub",
							Size = 12,
							Weight = Enum.FontWeight.Medium,
							Hug = true,
							LayoutOrder = 2,
						}),
					}),
					HeadLine = Roact.createElement(Divider, { LayoutOrder = 2 }),
					Body = Roact.createElement(ScrollBody, {
						Overlay = Roact.createElement(BusyOverlay, { Settled = props.Closing }),
						Action = Roact.createElement(InstallAction, { Height = 34 }),
						Flex = true,
						Gap = 10,
						Gutter = gutter,
						PaddingTop = 12,
						LayoutOrder = 3,
					}, {
						Titles = Roact.createElement(
							PackageTitles,
							{ Size = if tiny then 17 else 19, LayoutOrder = 1 }
						),
						Form = Roact.createElement(InstallForm, {
							Layout = if props.Width - gutter * 2 >= 256 then "pair" else "stacked",
							Settled = props.Closing,
							LayoutOrder = 2,
						}),
						Problems = Roact.createElement(InstallProblems, { Settled = props.Closing, LayoutOrder = 3 }),
					}),
				}),
			}),
		})
	end)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(FullPanel)
