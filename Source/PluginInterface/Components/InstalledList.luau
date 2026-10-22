local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)

local Badge = require(script.Parent.Common.Badge)
local InstalledRow = require(script.Parent.InstalledRow)
local Presence = require(script.Parent.Common.Presence)
local Text = require(script.Parent.Common.Text)

local selectionKey = require(script.Parent.Parent.Parent.PluginUtilities.selectionKey)
local withPalette = require(script.Parent.Parent.withPalette)

local GROUPS = {
	{ realm = "shared", heading = "Shared, in ReplicatedStorage" },
	{ realm = "server", heading = "Server, in ServerStorage" },
}

local InstalledList = Roact.Component:extend("InstalledList")

InstalledList.defaultProps = { Embedded = false, LayoutOrder = 0 }

function InstalledList:init()
	self.closeInline = function()
		self:setState({ leaving = Roact.None })
	end
end

--[[
	Follows which installed package has its options open in place, so the one that closes can fold shut, unless its
		row has gone.
]]
function InstalledList.getDerivedStateFromProps(props, state)
	local selection = props.store.selection
	local open = if props.Inline and selection and selection.kind == "installed" then selectionKey(selection) else nil
	local updates = Presence.follow(state, open, props.store)
	local present = {}

	for _, package in props.store.installed do
		present[selectionKey({ kind = "installed", alias = package.alias, realm = package.realm })] = true
	end

	return Presence.forget(updates, state, present)
end

--[[
	A realm's heading over its packages.
]]
function InstalledList:renderHeading(text: string, order: number)
	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
	}, {
		Padding = Roact.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 12),
		}),
		Heading = Roact.createElement(Text, { Text = text, Role = "sub", Size = 11, Weight = Enum.FontWeight.Medium }),
	})
end

--[[
	The place's root dependencies grouped by realm, Shared first. Embedded, as the section under the results of a
		very tall widget, it carries its own Installed heading, does not scroll by itself, and places `Inline` under
		the selected package.
]]
function InstalledList:render()
	local props = self.props
	local store = props.store
	local selection = store.selection
	local leaving = self.state.leaving
	local rows = {
		Layout = Roact.createElement("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	local order = 1

	if props.Embedded then
		rows.Title = Roact.createElement(
			"Frame",
			{ BackgroundTransparency = 1, LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 34) },
			{
				Padding = Roact.createElement(
					"UIPadding",
					{ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12) }
				),
				Layout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				Label = Roact.createElement(Text, {
					Text = "Installed",
					Role = "strong",
					Weight = Enum.FontWeight.SemiBold,
					Hug = true,
					LayoutOrder = 1,
				}),
				Count = Roact.createElement(Badge, { Text = tostring(#store.installed), LayoutOrder = 2 }),
			}
		)
	end

	if #store.installed == 0 then
		rows.Empty = Roact.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
		}, {
			Padding = Roact.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
				PaddingTop = UDim.new(0, 16),
			}),
			Message = Roact.createElement(Text, {
				Text = "Nothing is installed in this place yet. Search on Browse to add a package.",
				Role = "sub",
				Size = 12,
				Wrap = true,
			}),
		})
	end

	for _, group in GROUPS do
		local members = {}

		for _, package in store.installed do
			if package.realm == group.realm then
				table.insert(members, package)
			end
		end

		if #members == 0 then
			continue
		end

		table.sort(members, function(left, right)
			return left.alias < right.alias
		end)

		rows[`Group {group.realm}`] = self:renderHeading(group.heading, order)
		order += 1

		for _, package in members do
			local key = selectionKey({ kind = "installed", alias = package.alias, realm = package.realm })
			local selected = selectionKey(selection) == key

			rows[`Installed {package.alias}`] = Roact.createElement(InstalledRow, {
				Package = package,
				Selected = selected,
				LayoutOrder = order,
				OnActivated = store.onInstalledSelected,
			})
			order += 1

			if selected and props.Inline then
				rows[`Inline options {key}`] = Presence.slot(props.Inline, order)
				order += 1
			end

			if leaving and props.Inline and leaving.key == key then
				rows[`Closing inline options {key}`] = Presence.slot(props.Inline, order, leaving, self.closeInline)
				order += 1
			end
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
end)(InstalledList)
