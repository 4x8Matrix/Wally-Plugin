local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)
local Sift = require(script.Parent.Parent.Parent.Packages.Sift)

local FullPanel = require(script.Parent.Surfaces.FullPanel)
local InlineOptions = require(script.Parent.InlineOptions)
local InstalledList = require(script.Parent.InstalledList)
local NoticeBar = require(script.Parent.NoticeBar)
local PluginContext = require(script.Parent.Parent.Parent.PluginContext)
local Presence = require(script.Parent.Common.Presence)
local ResultList = require(script.Parent.ResultList)
local Sheet = require(script.Parent.Surfaces.Sheet)
local SidePanel = require(script.Parent.Surfaces.SidePanel)
local StripPanel = require(script.Parent.Surfaces.StripPanel)
local Tabs = require(script.Parent.Tabs)
local TextField = require(script.Parent.Common.TextField)

local classifyWidget = require(script.Parent.Parent.Parent.PluginUtilities.classifyWidget)
local withPalette = require(script.Parent.Parent.withPalette)

local Shelf = Roact.Component:extend("Shelf")

Shelf.defaultProps = {}

function Shelf:init()
	self:setState({ size = Vector2.new(320, 560) })
end

--[[
	The registry search field, with the number found once a search has answered.
]]
function Shelf:renderSearch(layout, order: number)
	local store = self.props.store
	local search = store.search
	local compact = layout.widthClass == "xs" or layout.strip
	local field = Roact.createElement(TextField, {
		Text = store.query,
		Placeholder = "Search the Wally registry",
		Icon = PluginContext.PluginSettings.Icons.Search,
		Hint = if search.status ~= "done" or layout.widthClass == "xs"
			then ""
			elseif #search.results >= 100 then "100+ found"
			else `{#search.results} found`,
		Height = if compact then 28 else 32,
		OnChanged = store.onSearchTextUpdated,
		OnSubmitted = store.onSearchSubmitted,
	})

	if layout.strip then
		return Roact.createElement(
			"Frame",
			{ BackgroundTransparency = 1, LayoutOrder = order, Size = UDim2.fromOffset(0, 28) },
			{
				Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
				Field = field,
			}
		)
	end

	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
	}, {
		Padding = Roact.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, if compact then 10 else 14),
			PaddingRight = UDim.new(0, if compact then 10 else 14),
			PaddingTop = UDim.new(0, if compact then 8 else 10),
		}),
		Field = field,
	})
end

--[[
	The list the current tab shows, with the install options opened in place when the layout calls for it. Its rows
		take the style for the room the list has, which beside a panel is less than the widget's width.
]]
function Shelf:renderList(layout, width: number)
	local store = self.props.store
	local rows = Sift.Dictionary.merge(layout, { widthClass = layout.rowClass })
	local inline = if layout.surface == "inline"
		then function(closing: boolean, closed: () -> (), order: number)
			return Roact.createElement(
				InlineOptions,
				{ Width = width, Closing = closing, OnClosed = closed, LayoutOrder = order }
			)
		end
		else nil

	if layout.stackedTabs then
		return Roact.createElement("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 4,
			Size = UDim2.fromScale(1, 1),
		}, {
			Layout = Roact.createElement("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
			Results = Roact.createElement(ResultList, {
				Layout = rows,
				Embedded = true,
				Inline = inline,
				LayoutOrder = 1,
			}),
			["Installed section"] = Roact.createElement(InstalledList, {
				Layout = rows,
				Embedded = true,
				Inline = inline,
				LayoutOrder = 2,
			}),
		})
	end

	if store.tab == "installed" then
		return Roact.createElement(InstalledList, { Layout = rows })
	end

	return Roact.createElement(ResultList, { Layout = rows })
end

--[[
	The whole widget: picks the row style and the install surface for its size by `classifyWidget`, then lays out the
		tabs, the search field, the list, the surface and the notice bar. The size is measured from the widget, or
		given as `LayoutSize` by specs and previews.
]]
function Shelf:render()
	local props = self.props
	local store = props.store
	local size = props.LayoutSize or self.state.size
	local layout = classifyWidget(size.X, size.Y)
	local selected = if store.selection then true else false
	local full = layout.surface == "full" and selected
	local column = {
		Layout = Roact.createElement("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	local tabs = Roact.createElement(Tabs, {
		Active = store.tab,
		InstalledCount = #store.installed,
		Compact = layout.widthClass == "xs",
		Strip = layout.strip,
		LayoutOrder = 1,
		OnSelected = store.onTabSelected,
	})

	if layout.strip then
		column["Top bar"] = Roact.createElement(
			"Frame",
			{ BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40) },
			{
				Padding = Roact.createElement("UIPadding", { PaddingRight = UDim.new(0, 12) }),
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 16),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Tabs = tabs,
				Search = if store.tab == "browse" then self:renderSearch(layout, 2) else nil,
			}
		)
	else
		if not layout.stackedTabs then
			column.Tabs = tabs
		end

		if not full and (store.tab == "browse" or layout.stackedTabs) then
			column.Search = self:renderSearch(layout, 2)
		end
	end

	local body = {}

	if layout.widthClass == "l" then
		body.Layout = Roact.createElement(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }
		)
		body.List = Roact.createElement(
			"Frame",
			{ BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.fromScale(0, 1) },
			{
				Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
				List = self:renderList(layout, size.X),
			}
		)

		if layout.strip then
			body["Strip panel"] = Roact.createElement(
				StripPanel,
				{ Width = layout.panelWidth, Line = layout.surface == "stripLine", LayoutOrder = 2 }
			)
		else
			body["Side panel"] = Roact.createElement(SidePanel, { Width = layout.panelWidth, LayoutOrder = 2 })
		end
	else
		body.List = if full then nil else self:renderList(layout, size.X)
		body["Full panel"] = Roact.createElement(Presence, {
			Present = full,
			State = store,
			Name = "Full panel",
			render = function(closing: boolean, closed: () -> ())
				return Roact.createElement(FullPanel, { Width = size.X, Closing = closing, OnClosed = closed })
			end,
		})
	end

	body.Flex = Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill })
	column.Body = Roact.createElement("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
	}, body)
	column.Notice = Roact.createElement(NoticeBar, { Width = size.X, LayoutOrder = 4 })

	return withPalette(function(palette)
		return Roact.createElement("Frame", {
			BackgroundColor3 = palette.background,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
			[Roact.Change.AbsoluteSize] = function(frame)
				if not props.LayoutSize and frame.AbsoluteSize ~= self.state.size and frame.AbsoluteSize.X > 0 then
					self:setState({ size = frame.AbsoluteSize })
				end
			end,
		}, {
			Column = Roact.createElement("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, column),
			Sheet = Roact.createElement(Presence, {
				Present = layout.surface == "sheet" and selected,
				State = store,
				Name = "Sheet",
				render = function(closing: boolean, closed: () -> ())
					return Roact.createElement(
						Sheet,
						{ Width = size.X, Height = size.Y, Closing = closing, OnClosed = closed }
					)
				end,
			}),
		})
	end)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(Shelf)
