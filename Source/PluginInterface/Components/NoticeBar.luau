local TextService = game:GetService("TextService")

local Flipper = require(script.Parent.Parent.Parent.Packages.Flipper)
local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactFlipper = require(script.Parent.Parent.Parent.Packages.RoactFlipper)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)

local Icon = require(script.Parent.Common.Icon)
local IconButton = require(script.Parent.Common.IconButton)
local Link = require(script.Parent.Common.Link)
local Motion = require(script.Parent.Parent.Motion)
local PluginContext = require(script.Parent.Parent.Parent.PluginContext)
local Shield = require(script.Parent.Common.Shield)
local Text = require(script.Parent.Common.Text)

local withPalette = require(script.Parent.Parent.withPalette)

local ICONS = {
	installed = PluginContext.PluginSettings.Icons.Success,
	removed = PluginContext.PluginSettings.Icons.Success,
	failed = PluginContext.PluginSettings.Icons.Error,
	lostIndex = PluginContext.PluginSettings.Icons.Warning,
}

local NoticeBar = Roact.Component:extend("NoticeBar")

NoticeBar.defaultProps = { Width = 320, LayoutOrder = 0 }

--[[
	How much room a run of text takes at 12 px, wrapped at `width`.
]]
local function measure(text: string, font: Enum.Font, width: number): Vector2
	return TextService:GetTextSize(text, 12, font, Vector2.new(width, 10000))
end

function NoticeBar:init()
	self.riseMotor = Flipper.SingleMotor.new(0)
	self.rise = RoactFlipper.getBinding(self.riseMotor)
end

--[[
	Keeps the notice it last showed while that notice slides away after being dismissed or cleared.
]]
function NoticeBar.getDerivedStateFromProps(props, state)
	if props.store.notice then
		return { shown = props.store.notice, closing = false }
	end

	if state.shown and not state.closing then
		return { closing = true }
	end

	return
end

--[[
	Rises into view whenever a new notice arrives, and slides away when it goes.
]]
function NoticeBar:didUpdate(previous, previousState)
	if self.props.store.notice and self.props.store.notice ~= previous.store.notice then
		Motion:Snap(self.riseMotor, 0)
		self.riseMotor:setGoal(Motion:Goal(1, "sheet"))
	elseif self.state.closing and not previousState.closing then
		self.riseMotor:setGoal(Motion:Goal(0, "push"))
	end
end

function NoticeBar:didMount()
	self.riseMotor:onComplete(function()
		if self.state.closing then
			self:setState({ shown = Roact.None, closing = false })
		end
	end)
	self.riseMotor:setGoal(Motion:Goal(1, "sheet"))
end

function NoticeBar:willUnmount()
	self.riseMotor:destroy()
end

--[[
	The outcome of the last operation, with what can follow it: Show in Explorer and Undo after an install, Undo
		after a removal, and the warning when Rojo live sync took an index. The message wraps at the width the icon,
		links and close button leave it; when that would leave it too narrow, the links move to a line below. The bar's
		height is worked out from what it holds rather than sized automatically, because automatic sizing would count
		the rising content's offset and push the list above it up and back down as it rises. A notice that goes slides
		down while the bar shrinks away, giving the list its room back smoothly.
]]
function NoticeBar:render()
	local props = self.props
	local store = props.store
	local notice = self.state.shown
	local closing = self.state.closing
	local paddingLeft = 12
	local paddingRight = 10
	local paddingY = 8
	local gap = 8
	local iconSize = 14
	local linkHeight = math.ceil(12 * 1.3)

	if not notice then
		return
	end

	local links = {}
	local linkWidth = 0

	if notice.kind == "installed" then
		links["Show in Explorer"] = Roact.createElement(Link, {
			Text = "Show in Explorer",
			LayoutOrder = 3,
			OnActivated = store.onShowInExplorer,
		})
		linkWidth += measure("Show in Explorer", Enum.Font.BuilderSansMedium, 1000).X + gap
	end

	if notice.kind == "installed" or notice.kind == "removed" then
		links.Undo = Roact.createElement(Link, { Text = "Undo", LayoutOrder = 4, OnActivated = store.onUndo })
		linkWidth += measure("Undo", Enum.Font.BuilderSansMedium, 1000).X + gap
	end

	local fixed = paddingLeft + paddingRight + iconSize * 2 + gap * 2
	local inline = props.Width - fixed - linkWidth >= 140
	local messageWidth = math.max(props.Width - fixed - (if inline then linkWidth else 0), 40)
	local messageHeight = measure(notice.message, Enum.Font.BuilderSans, messageWidth).Y
	local linksBelow = not inline and linkWidth > 0
	local rowHeight = math.max(messageHeight, iconSize, if inline and linkWidth > 0 then linkHeight else 0)
	local height = paddingY * 2 + rowHeight + (if linksBelow then 4 + linkHeight else 0)
	local row = {
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		Icon = Roact.createElement(
			Icon,
			{ Image = ICONS[notice.kind], Size = iconSize, Tinted = false, LayoutOrder = 1 }
		),
		Message = Roact.createElement(Text, {
			Text = notice.message,
			Role = "text",
			Size = 12,
			Wrap = true,
			Width = UDim.new(0, messageWidth),
			Height = messageHeight,
			LayoutOrder = 2,
		}),
	}

	if inline then
		for key, link in links do
			row[key] = link
		end
	end

	return withPalette(function(palette)
		local below

		row.Dismiss = Roact.createElement(IconButton, {
			Image = PluginContext.PluginSettings.Icons.Close,
			Size = iconSize,
			LayoutOrder = 5,
			OnActivated = store.onNoticeDismissed,
		})

		if linksBelow then
			links.Layout = Roact.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			links.Padding = Roact.createElement("UIPadding", { PaddingLeft = UDim.new(0, iconSize + gap) })
			below = Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
			}, links)
		end

		return Roact.createElement("Frame", {
			BackgroundColor3 = palette.surface,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = props.LayoutOrder,
			Size = if closing
				then self.rise:map(function(value)
					return UDim2.new(1, 0, 0, height * value)
				end)
				else UDim2.new(1, 0, 0, height),
		}, {
			Shield = if closing then Roact.createElement(Shield) else nil,
			Edge = Roact.createElement("Frame", {
				BackgroundColor3 = palette.divider,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
				ZIndex = 2,
			}),
			Notice = Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Position = self.rise:map(function(value)
					return UDim2.fromOffset(0, (1 - value) * 32)
				end),
				Size = UDim2.fromScale(1, 0),
			}, {
				Padding = Roact.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, paddingY),
					PaddingLeft = UDim.new(0, paddingLeft),
					PaddingRight = UDim.new(0, paddingRight),
					PaddingTop = UDim.new(0, paddingY),
				}),
				Layout = Roact.createElement(
					"UIListLayout",
					{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
				),
				Row = Roact.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
				}, row),
				Links = below,
			}),
		})
	end)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(NoticeBar)
