local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)

local Text = require(script.Parent.Common.Text)

local findInstalled = require(script.Parent.Parent.Parent.PluginUtilities.findInstalled)
local toPascalCase = require(script.Parent.Parent.Parent.PluginUtilities.toPascalCase)

local PackageTitles = Roact.Component:extend("PackageTitles")

PackageTitles.defaultProps = { Size = 20, Description = true, Flex = false, LayoutOrder = 0 }

--[[
	The title, id and description of what the install surface is about: a result is titled by its name in PascalCase,
		an installed package by its alias. `Flex` lets it take the room a horizontal row has left.
]]
function PackageTitles:render()
	local props = self.props
	local store = props.store
	local selection = store.selection
	local installed = findInstalled(store.installed, selection)
	local title = ""
	local id = ""
	local description = ""

	if selection and selection.kind == "result" then
		title = toPascalCase(selection.name)
		id = `{selection.scope}/{selection.name}`

		for _, result in store.search.results do
			if result.scope == selection.scope and result.name == selection.name then
				description = result.description

				break
			end
		end
	elseif selection then
		title = selection.alias
		id = if installed then `{installed.scope}/{installed.name}` else ""
	end

	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, {
		Flex = if props.Flex then Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) else nil,
		Layout = Roact.createElement(
			"UIListLayout",
			{ Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Title = Roact.createElement(Text, {
			Text = title,
			Role = "strong",
			Size = props.Size,
			Weight = Enum.FontWeight.SemiBold,
			LayoutOrder = 1,
		}),
		Id = Roact.createElement(Text, { Text = id, Role = "sub", Size = 12, Mono = true, LayoutOrder = 2 }),
		Description = if props.Description and description ~= ""
			then Roact.createElement(
				Text,
				{ Text = description, Role = "sub", Size = 12, Wrap = true, LayoutOrder = 3 }
			)
			else nil,
	})
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(PackageTitles)
