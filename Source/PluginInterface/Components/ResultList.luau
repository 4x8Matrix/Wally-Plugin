local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)

local Divider = require(script.Parent.Common.Divider)
local ErrorBlock = require(script.Parent.Common.ErrorBlock)
local Link = require(script.Parent.Common.Link)
local Presence = require(script.Parent.Common.Presence)
local ResultRow = require(script.Parent.ResultRow)
local Spinner = require(script.Parent.Common.Spinner)
local Text = require(script.Parent.Common.Text)

local selectionKey = require(script.Parent.Parent.Parent.PluginUtilities.selectionKey)
local withPalette = require(script.Parent.Parent.withPalette)

local ResultList = Roact.Component:extend("ResultList")

ResultList.defaultProps = { Embedded = false, LayoutOrder = 0 }

--[[
	The line shown instead of rows: an invitation before any search, progress while searching, the registry's failure
		with Retry, or that nothing matched.
]]
function ResultList:renderMessage()
	local store = self.props.store
	local search = store.search
	local children = {
		Padding = Roact.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 16),
		}),
		Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Wraps = true,
		}),
	}

	if search.status == "searching" then
		children.Spinner = Roact.createElement(Spinner, { Size = 14, LayoutOrder = 1 })
		children.Message = Roact.createElement(
			Text,
			{ Text = `Searching for "{store.query}"`, Role = "sub", Size = 12, Flex = true, LayoutOrder = 2 }
		)
	elseif search.status == "failed" then
		children.Message = Roact.createElement(ErrorBlock, {
			Text = `The registry didn't answer: {search.message or "no reason given"}`,
			Size = 12,
			LayoutOrder = 1,
		})
		children.Retry =
			Roact.createElement(Link, { Text = "Retry", LayoutOrder = 2, OnActivated = store.onRetrySearch })
	elseif search.status == "done" then
		children.Message = Roact.createElement(
			Text,
			{ Text = `No packages match "{store.query}"`, Role = "sub", Size = 12, Wrap = true, LayoutOrder = 1 }
		)
	else
		children.Message = Roact.createElement(Text, {
			Text = "Search the Wally registry for a package to install",
			Role = "sub",
			Size = 12,
			Wrap = true,
			LayoutOrder = 1,
		})
	end

	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
	}, children)
end

function ResultList:init()
	self.closeInline = function()
		self:setState({ leaving = Roact.None })
	end
end

--[[
	Counts the result sets the list has shown, so its rows know when a new set arrives and fade in again, and follows
		which result has its options open in place, so the one that closes can fold shut, unless its row has gone.
]]
function ResultList.getDerivedStateFromProps(props, state)
	local store = props.store
	local selection = store.selection
	local open = if props.Inline and selection and selection.kind == "result" then selectionKey(selection) else nil
	local updates = Presence.follow(state, open, store)
	local present = {}

	for _, result in store.search.results do
		present[selectionKey({ kind = "result", scope = result.scope, name = result.name })] = true
	end

	if store.search.results ~= state.results then
		updates.results = store.search.results
		updates.generation = (state.generation or 0) + 1
	end

	return Presence.forget(updates, state, present)
end

--[[
	Package, Description and Latest headings above a wide widget's table.
]]
function ResultList:renderColumns()
	return Roact.createElement(
		"Frame",
		{ BackgroundTransparency = 1, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 28) },
		{
			Content = Roact.createElement("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
				Padding = Roact.createElement(
					"UIPadding",
					{ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }
				),
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 14),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Package = Roact.createElement(Text, {
					Text = "Package",
					Role = "dim",
					Size = 11,
					Weight = Enum.FontWeight.Medium,
					Width = UDim.new(0, 210),
					LayoutOrder = 1,
				}),
				Description = Roact.createElement(Text, {
					Text = "Description",
					Role = "dim",
					Size = 11,
					Weight = Enum.FontWeight.Medium,
					Flex = true,
					LayoutOrder = 2,
				}),
				Latest = Roact.createElement(Text, {
					Text = "Latest",
					Role = "dim",
					Size = 11,
					Weight = Enum.FontWeight.Medium,
					Width = UDim.new(0, 52),
					XAlignment = Enum.TextXAlignment.Right,
					LayoutOrder = 3,
				}),
			}),
			Underline = Roact.createElement(
				"Frame",
				{ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1) },
				{
					Line = Roact.createElement(Divider),
				}
			),
		}
	)
end

--[[
	Registry results for the current search, one row per package in the layout's row style. When the layout opens the
		install options in place, `Inline` is placed straight under the selected row.
]]
function ResultList:render()
	local props = self.props
	local store = props.store
	local layout = props.Layout
	local selection = store.selection
	local leaving = self.state.leaving
	local rows = {
		Layout = Roact.createElement("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}

	if layout.widthClass == "l" and not layout.strip then
		rows.Columns = self:renderColumns()
	end

	if #store.search.results == 0 then
		rows.Message = self:renderMessage()
	end

	for index, result in store.search.results do
		local key = selectionKey({ kind = "result", scope = result.scope, name = result.name })
		local selected = selectionKey(selection) == key

		rows[`Result {result.scope}/{result.name}`] = Roact.createElement(ResultRow, {
			Result = result,
			WidthClass = layout.widthClass,
			Strip = layout.strip,
			Selected = selected,
			Delay = if self.state.generation > 1 then math.min(index - 1, 11) * 0.025 else nil,
			Generation = self.state.generation,
			LayoutOrder = index * 2,
			OnActivated = store.onResultSelected,
		})

		if selected and props.Inline then
			rows[`Inline options {key}`] = Presence.slot(props.Inline, index * 2 + 1)
		end

		if leaving and props.Inline and leaving.key == key then
			rows[`Closing inline options {key}`] = Presence.slot(props.Inline, index * 2 + 1, leaving, self.closeInline)
		end
	end

	return withPalette(function(palette)
		if props.Embedded then
			return Roact.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = props.LayoutOrder,
				Size = UDim2.fromScale(1, 0),
			}, rows)
		end

		return Roact.createElement("ScrollingFrame", {
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			LayoutOrder = props.LayoutOrder,
			ScrollBarImageColor3 = palette.dimText,
			ScrollBarThickness = 4,
			Size = UDim2.fromScale(1, 1),
		}, rows)
	end)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(ResultList)
