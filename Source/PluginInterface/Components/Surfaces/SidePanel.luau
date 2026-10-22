local Roact = require(script.Parent.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Parent.Packages.RoactRodux)

local BusyOverlay = require(script.Parent.Parent.Common.BusyOverlay)
local Crossfade = require(script.Parent.Parent.Common.Crossfade)
local Divider = require(script.Parent.Parent.Common.Divider)
local InstallAction = require(script.Parent.Parent.InstallAction)
local InstallForm = require(script.Parent.Parent.InstallForm)
local InstallProblems = require(script.Parent.Parent.InstallProblems)
local PackageTitles = require(script.Parent.Parent.PackageTitles)
local ScrollBody = require(script.Parent.Parent.Common.ScrollBody)
local Text = require(script.Parent.Parent.Common.Text)

local selectionKey = require(script.Parent.Parent.Parent.Parent.PluginUtilities.selectionKey)
local withPalette = require(script.Parent.Parent.Parent.withPalette)

local SidePanel = Roact.Component:extend("SidePanel")

SidePanel.defaultProps = { Width = 300, LayoutOrder = 0 }

--[[
	The dependencies the chosen version brings along, for panels with room to say so.
]]
function SidePanel:renderDependencies(order: number)
	local store = self.props.store
	local dependencies = (store.detail.dependencies or {})[store.form.version or ""]
	local lines = if dependencies and #dependencies > 0
		then table.concat(dependencies, "\n")
		else `Nothing else, so only {store.form.alias} is added.`

	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
	}, {
		Layout = Roact.createElement(
			"UIListLayout",
			{ Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Label = Roact.createElement(Text, {
			Text = "Depends on",
			Role = "sub",
			Size = 11,
			Weight = Enum.FontWeight.Medium,
			LayoutOrder = 1,
		}),
		List = Roact.createElement(Text, {
			Text = lines,
			Role = "text",
			Size = 12,
			Mono = dependencies and #dependencies > 0,
			Wrap = true,
			LayoutOrder = 2,
		}),
	})
end

--[[
	The install options beside the list in wide widgets, `Width` wide and open while browsing: the fields, then the
		dependencies the chosen version brings, then the action. The action follows them while everything fits; past
		that they scroll and the action pins at the bottom.
]]
function SidePanel:render()
	local props = self.props
	local store = props.store
	local layout = if props.Width - 32 >= 256 then "pair" else "stacked"

	return withPalette(function(palette)
		local content

		if not store.selection then
			content = {
				Padding = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingTop = UDim.new(0, 18),
				}),
				Empty = Roact.createElement(Text, {
					Text = "Pick a package to see its versions and install it",
					Role = "sub",
					Size = 12,
					Wrap = true,
				}),
			}
		else
			content = {
				Body = Roact.createElement(ScrollBody, {
					Overlay = Roact.createElement(BusyOverlay),
					Action = Roact.createElement(InstallAction),
				}, {
					Titles = Roact.createElement(PackageTitles, { LayoutOrder = 1 }),
					Form = Roact.createElement(InstallForm, { Layout = layout, LayoutOrder = 2 }),
					Problems = Roact.createElement(InstallProblems, { LayoutOrder = 3 }),
					Line = Roact.createElement(Divider, { LayoutOrder = 4 }),
					Dependencies = self:renderDependencies(5),
				}),
			}
		end

		return Roact.createElement("Frame", {
			BackgroundColor3 = palette.surface,
			BorderSizePixel = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.new(0, props.Width, 1, 0),
		}, {
			Edge = Roact.createElement("Frame", {
				BackgroundColor3 = palette.divider,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 1, 1, 0),
				ZIndex = 2,
			}),
			Content = Roact.createElement(Crossfade, { Key = selectionKey(store.selection) or "" }, content),
		})
	end)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(SidePanel)
