local Flipper = require(script.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Packages.RoactFlipper)

local Badge = require(script.Parent.Common.Badge)
local Divider = require(script.Parent.Common.Divider)
local Motion = require(script.Parent.Parent.Motion)
local Text = require(script.Parent.Common.Text)

local withPalette = require(script.Parent.Parent.withPalette)

local Tabs = Roact.Component:extend("Tabs")

Tabs.defaultProps = {
	Active = "browse",
	InstalledCount = 0,
	Compact = false,
	Strip = false,
	LayoutOrder = 0,
	OnSelected = function() end,
}

function Tabs:init()
	self.barRef = Roact.createRef()
	self.tabRefs = { browse = Roact.createRef(), installed = Roact.createRef() }
	self.indicatorMotor = Flipper.GroupMotor.new({ offset = 0, width = 0 })
	self.indicator = RoactFlipper.getBinding(self.indicatorMotor)
	self.hoverMotor = Flipper.SingleMotor.new(0)
	self.hover = RoactFlipper.getBinding(self.hoverMotor)
	self.hoverPlace, self.setHoverPlace = Roact.createBinding({ offset = 0, width = 0 })
	self.placed = false
end

--[[
	Shows a faint line under an inactive tab while the pointer is over it, so it reads as something to click.
]]
function Tabs:hoverOver(key: string)
	local bar = self.barRef:getValue()
	local tab = self.tabRefs[key]:getValue()

	if not bar or not tab or key == self.props.Active then
		return
	end

	self.setHoverPlace({ offset = tab.AbsolutePosition.X - bar.AbsolutePosition.X, width = tab.AbsoluteSize.X })
	self.hoverMotor:setGoal(Motion:Goal(1, "hover"))
end

--[[
	Moves the indicator under the active tab: at once the first time it can be measured, on its spring after that.
]]
function Tabs:moveIndicator()
	local bar = self.barRef:getValue()
	local tab = self.tabRefs[self.props.Active]:getValue()

	if not bar or not tab or tab.AbsoluteSize.X == 0 then
		return
	end

	local offset = tab.AbsolutePosition.X - bar.AbsolutePosition.X
	local width = tab.AbsoluteSize.X

	if self.placed then
		self.indicatorMotor:setGoal({ offset = Motion:Goal(offset, "tab"), width = Motion:Goal(width, "tab") })
	else
		self.indicatorMotor:setGoal({ offset = Flipper.Instant.new(offset), width = Flipper.Instant.new(width) })
		self.placed = true
	end
end

function Tabs:didMount()
	self:moveIndicator()
end

function Tabs:didUpdate()
	self:moveIndicator()
end

function Tabs:willUnmount()
	self.indicatorMotor:destroy()
	self.hoverMotor:destroy()
end

--[[
	One tab: its label, the installed count on Installed, and a click that selects it.
]]
function Tabs:renderTab(key: string, label: string, order: number)
	local props = self.props
	local active = props.Active == key

	return Roact.createElement("TextButton", {
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromScale(0, 1),
		Text = "",
		[Roact.Ref] = self.tabRefs[key],
		[Roact.Change.AbsoluteSize] = function()
			self:moveIndicator()
		end,
		[Roact.Event.Activated] = function()
			props.OnSelected(key)
		end,
		[Roact.Event.MouseEnter] = function()
			self:hoverOver(key)
		end,
		[Roact.Event.MouseLeave] = function()
			self.hoverMotor:setGoal(Motion:Goal(0, "hover"))
		end,
	}, {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Label = Roact.createElement(Text, {
			Text = label,
			Role = if active then "strong" else "sub",
			Size = if props.Compact then 12 else 13,
			Weight = Enum.FontWeight.Medium,
			Hug = true,
			LayoutOrder = 1,
		}),
		Count = if key == "installed"
			then Roact.createElement(Badge, { Text = tostring(props.InstalledCount), Active = active, LayoutOrder = 2 })
			else nil,
	})
end

--[[
	Browse and Installed with a sliding accent indicator under the active one, and a faint line under the other while
		the pointer is over it.
]]
function Tabs:render()
	local props = self.props
	local height = if props.Strip then 40 elseif props.Compact then 34 else 38

	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			AutomaticSize = if props.Strip then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = if props.Strip then UDim2.fromOffset(0, height) else UDim2.new(1, 0, 0, height),
			[Roact.Ref] = self.barRef,
			[Roact.Change.AbsolutePosition] = function()
				self:moveIndicator()
			end,
		}, {
			Row = Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0, 1),
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, if props.Compact then 10 else 14),
					PaddingRight = UDim.new(0, if props.Compact then 10 else 14),
				}),
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, if props.Compact then 14 else 20),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				["Tab Browse"] = self:renderTab("browse", "Browse", 1),
				["Tab Installed"] = self:renderTab("installed", "Installed", 2),
			}),
			["Tab hover"] = Roact.createElement("Frame", {
				BackgroundColor3 = palette.dimText,
				BackgroundTransparency = self.hover:map(function(value)
					return 1 - 0.6 * value
				end),
				BorderSizePixel = 0,
				Position = self.hoverPlace:map(function(place)
					return UDim2.new(0, place.offset, 1, -2)
				end),
				Size = self.hoverPlace:map(function(place)
					return UDim2.fromOffset(place.width, 2)
				end),
				ZIndex = 2,
			}),
			["Tab indicator"] = Roact.createElement("Frame", {
				BackgroundColor3 = palette.accent,
				BorderSizePixel = 0,
				Position = self.indicator:map(function(value)
					return UDim2.new(0, value.offset, 1, -2)
				end),
				Size = self.indicator:map(function(value)
					return UDim2.fromOffset(value.width, 2)
				end),
				ZIndex = 3,
			}),
			Underline = if props.Strip
				then nil
				else Roact.createElement("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 1, -1),
					Size = UDim2.new(1, 0, 0, 1),
				}, {
					Line = Roact.createElement(Divider),
				}),
		})
	end)
end

return Tabs
