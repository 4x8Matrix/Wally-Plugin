local Flipper = require(script.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Packages.RoactFlipper)

local BusyOverlay = require(script.Parent.Common.BusyOverlay)
local InstallAction = require(script.Parent.InstallAction)
local InstallForm = require(script.Parent.InstallForm)
local InstallProblems = require(script.Parent.InstallProblems)
local Motion = require(script.Parent.Parent.Motion)
local Shield = require(script.Parent.Common.Shield)

local withPalette = require(script.Parent.Parent.withPalette)

local InlineOptions = Roact.Component:extend("InlineOptions")

InlineOptions.defaultProps = { Width = 260, Closing = false, OnClosed = function() end, LayoutOrder = 0 }

function InlineOptions:init()
	self.revealMotor = Flipper.SingleMotor.new(if self.props.Closing then 1 else 0)
	self.reveal = RoactFlipper.getBinding(self.revealMotor)
	self.listHeight, self.setListHeight = Roact.createBinding(0)
	self:setState({ height = 0, resting = false })
end

--[[
	Unfolds under the row that was clicked as it mounts; a closing copy folds shut and says when it is gone.
]]
function InlineOptions:didMount()
	if self.props.Closing then
		self.revealMotor:onComplete(function()
			self.props.OnClosed()
		end)
		self.revealMotor:setGoal(Motion:Goal(0, "push"))
	else
		self.revealMotor:onComplete(function()
			self:setState({ resting = true })
		end)
		self.revealMotor:setGoal(Motion:Goal(1, "expand"))
	end
end

function InlineOptions:willUnmount()
	self.revealMotor:destroy()
end

--[[
	The install options opened in place under the chosen row, for widgets tall enough that a sheet would sit far
		from what was clicked. While it opens or closes, its height follows the content's measured height on the reveal
		spring, so the rows below slide down and back up, and a cover in its own colour fades away over it; once open
		it sizes itself, so a version list opening inside it grows it on the same frame. A closing copy keeps its
		natural height until it has measured it, and a clear shield takes its clicks. A clipping frame rather than a
		CanvasGroup, whose texture blurs at Studio's quality levels and is rebuilt on every change of size.
]]
function InlineOptions:render()
	local props = self.props
	local height = self.state.height
	local explicit = not self.state.resting and (not props.Closing or height > 0)

	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			AutomaticSize = if explicit then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
			BackgroundColor3 = palette.surface,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = props.LayoutOrder,
			Size = if explicit
				then self.reveal:map(function(value)
					return UDim2.new(1, 0, 0, height * value)
				end)
				else UDim2.fromScale(1, 0),
		}, {
			Shield = if props.Closing then Roact.createElement(Shield, { ZIndex = 10 }) else nil,
			Cover = Roact.createElement("Frame", {
				BackgroundColor3 = palette.surface,
				BackgroundTransparency = self.reveal,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Visible = self.reveal:map(function(value)
					return value < 0.99
				end),
				ZIndex = 9,
			}),
			Bar = Roact.createElement("Frame", {
				BackgroundColor3 = palette.accent,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 2, 1, 0),
				ZIndex = 2,
			}),
			Content = Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				[Roact.Change.AbsoluteSize] = function(frame)
					if frame.AbsoluteSize.Y ~= self.state.height then
						self:setState({ height = frame.AbsoluteSize.Y })
					end
				end,
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 14),
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 14),
					PaddingTop = UDim.new(0, 12),
				}),
				Layout = Roact.createElement(
					"UIListLayout",
					{ Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }
				),
				Fields = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
				}, {
					List = Roact.createElement("Frame", {
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 0),
						[Roact.Change.AbsoluteSize] = function(frame)
							self.setListHeight(frame.AbsoluteSize.Y)
						end,
					}, {
						Layout = Roact.createElement(
							"UIListLayout",
							{ Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }
						),
						Form = Roact.createElement(InstallForm, {
							Layout = if props.Width - 28 >= 256 then "pair" else "stacked",
							Settled = props.Closing,
							LayoutOrder = 1,
						}),
						Problems = Roact.createElement(InstallProblems, { Settled = props.Closing, LayoutOrder = 2 }),
					}),
					Overlay = Roact.createElement(BusyOverlay, { Settled = props.Closing, Height = self.listHeight }),
				}),
				Action = Roact.createElement(InstallAction, { LayoutOrder = 2 }),
			}),
		})
	end)
end

return InlineOptions
