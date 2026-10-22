local Flipper = require(script.Parent.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Parent.Packages.RoactFlipper)
local RoactRodux = require(script.Parent.Parent.Parent.Parent.Packages.RoactRodux)

local BusyOverlay = require(script.Parent.Parent.Common.BusyOverlay)
local IconButton = require(script.Parent.Parent.Common.IconButton)
local InstallAction = require(script.Parent.Parent.InstallAction)
local InstallForm = require(script.Parent.Parent.InstallForm)
local InstallProblems = require(script.Parent.Parent.InstallProblems)
local Motion = require(script.Parent.Parent.Parent.Motion)
local PackageTitles = require(script.Parent.Parent.PackageTitles)
local PluginContext = require(script.Parent.Parent.Parent.Parent.PluginContext)
local ScrollBody = require(script.Parent.Parent.Common.ScrollBody)
local Shield = require(script.Parent.Parent.Common.Shield)

local withPalette = require(script.Parent.Parent.Parent.withPalette)

local Sheet = Roact.Component:extend("Sheet")

Sheet.defaultProps = { Width = 320, Height = 560, Closing = false, OnClosed = function() end }

function Sheet:init()
	self.openMotor = Flipper.SingleMotor.new(if self.props.Closing then 1 else 0)
	self.open = RoactFlipper.getBinding(self.openMotor)
	self:setState({ headHeight = 0 })
end

--[[
	Rises from the bottom edge on its spring as it mounts; a closing copy slides back down instead and says when it
		is gone.
]]
function Sheet:didMount()
	if self.props.Closing then
		self.openMotor:onComplete(function()
			self.props.OnClosed()
		end)
		self.openMotor:setGoal(Motion:Goal(0, "push"))
	else
		self.openMotor:setGoal(Motion:Goal(1, "sheet"))
	end
end

function Sheet:willUnmount()
	self.openMotor:destroy()
end

--[[
	The install options as a sheet over the list, with the list dimmed behind it. The sheet hugs the form up to nine
		tenths of the widget's height; past that the form scrolls and the action pins at the bottom. Clicking the dimmed
		list or the close button puts the sheet away. While `Closing`, a clear shield over everything takes the clicks,
		so the copy sliding away cannot be used.
]]
function Sheet:render()
	local props = self.props
	local store = props.store
	local bodyHeight = math.max(props.Height * 0.9 - 34 - self.state.headHeight, 120)

	return withPalette(function(palette)
		return Roact.createFragment({
			Scrim = Roact.createElement("Frame", {
				BackgroundColor3 = palette.scrim,
				BackgroundTransparency = self.open:map(function(value)
					return 1 - 0.35 * value
				end),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
			}, {
				Click = if props.Closing
					then nil
					else Roact.createElement("TextButton", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = "",
						[Roact.Event.Activated] = store.onSelectionCleared,
					}),
			}),
			Shield = if props.Closing then Roact.createElement(Shield, { ZIndex = 7 }) else nil,
			Sheet = Roact.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = palette.surface,
				BorderSizePixel = 0,
				Position = self.open:map(function(value)
					return UDim2.fromScale(0, 2 - value)
				end),
				Size = UDim2.fromScale(1, 0),
				ZIndex = 6,
			}, {
				Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Padding = Roact.createElement("UIPadding", { PaddingTop = UDim.new(0, 10) }),
				Layout = Roact.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Grabber = Roact.createElement("Frame", {
					BackgroundColor3 = palette.dimText,
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(32, 4),
				}, {
					Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 2) }),
				}),
				Head = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0),
					[Roact.Change.AbsoluteSize] = function(frame)
						if frame.AbsoluteSize.Y ~= self.state.headHeight then
							self:setState({ headHeight = frame.AbsoluteSize.Y })
						end
					end,
				}, {
					Padding = Roact.createElement(
						"UIPadding",
						{ PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }
					),
					Layout = Roact.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Titles = Roact.createElement(PackageTitles, { Flex = true, LayoutOrder = 1 }),
					Close = Roact.createElement(IconButton, {
						Image = PluginContext.PluginSettings.Icons.Close,
						LayoutOrder = 2,
						OnActivated = store.onSelectionCleared,
					}),
				}),
				Body = Roact.createElement(ScrollBody, {
					Overlay = Roact.createElement(BusyOverlay, { Settled = props.Closing }),
					Action = Roact.createElement(InstallAction),
					MaxHeight = bodyHeight,
					PaddingTop = 2,
					PaddingBottom = 18,
					LayoutOrder = 3,
				}, {
					Form = Roact.createElement(InstallForm, {
						Layout = if props.Width - 32 >= 256 then "pair" else "stacked",
						Settled = props.Closing,
						LayoutOrder = 1,
					}),
					Problems = Roact.createElement(InstallProblems, { Settled = props.Closing, LayoutOrder = 2 }),
				}),
			}),
		})
	end)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(Sheet)
