local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)

local ErrorBlock = require(script.Parent.Common.ErrorBlock)
local RealmSwitch = require(script.Parent.RealmSwitch)
local Text = require(script.Parent.Common.Text)
local TextField = require(script.Parent.Common.TextField)
local VersionSelect = require(script.Parent.VersionSelect)

local findInstalled = require(script.Parent.Parent.Parent.PluginUtilities.findInstalled)

local InstallForm = Roact.Component:extend("InstallForm")

InstallForm.defaultProps = { Layout = "pair", Settled = false, LayoutOrder = 0 }

--[[
	A labelled field with its error, when it has one, written underneath. In a row it flexes to share the width.
]]
function InstallForm:renderField(label: string, control, problem: string?, order: number, flex: boolean)
	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
	}, {
		Flex = if flex then Roact.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) else nil,
		Layout = Roact.createElement(
			"UIListLayout",
			{ Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Label = Roact.createElement(
			Text,
			{ Text = label, Role = "sub", Size = 11, Weight = Enum.FontWeight.Medium, LayoutOrder = 1 }
		),
		Control = control,
		Error = if problem
			then Roact.createElement(ErrorBlock, { Text = problem, Settled = self.props.Settled, LayoutOrder = 3 })
			else nil,
	})
end

--[[
	The version, the realm and the name in Packages for the selected package. `pair` puts version and realm side by
		side, `stacked` gives each its own row, and `strip` and `line` put all three on one row.
]]
function InstallForm:render()
	local props = self.props
	local store = props.store
	local detail = store.detail
	local form = store.form
	local errors = form.errors or {}
	local installed = store.selection and store.selection.kind == "installed"
	local installedPackage = findInstalled(store.installed, store.selection)
	local version = if detail.status == "failed"
		then Roact.createElement(ErrorBlock, {
			Text = `Couldn't read the versions: {detail.message or "no reason given"}`,
			Size = 12,
			Settled = props.Settled,
			LayoutOrder = 2,
		})
		else Roact.createElement(VersionSelect, {
			Versions = detail.versions,
			Latest = detail.latest,
			Installed = if installedPackage then installedPackage.version else nil,
			Value = form.version,
			Loading = detail.status == "loading",
			LayoutOrder = 2,
			OnSelected = function(chosen: string)
				store.onFormChanged({ version = chosen })
			end,
		})
	local realm = Roact.createElement(RealmSwitch, {
		Value = form.realm,
		ServerOnly = form.version and detail.realms[form.version] == "server",
		Locked = installed,
		Caption = props.Layout ~= "line",
		LayoutOrder = 2,
		OnChanged = function(chosen: string)
			store.onFormChanged({ realm = chosen })
		end,
	})
	local name = Roact.createElement(TextField, {
		Text = form.alias,
		Mono = true,
		Error = if errors.name then true else false,
		ReadOnly = installed,
		LayoutOrder = 2,
		OnChanged = function(alias: string)
			store.onFormChanged({ alias = alias })
		end,
	})
	local fields = {
		["Field Version"] = self:renderField("Version", version, errors.version, 1, props.Layout ~= "stacked"),
		["Field Realm"] = self:renderField("Goes into", realm, nil, 2, props.Layout ~= "stacked"),
		["Field Name"] = self:renderField(
			"Name in Packages",
			name,
			errors.name,
			3,
			props.Layout == "strip" or props.Layout == "line"
		),
	}
	local row = function(children, order: number)
		children.Layout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		})

		return Roact.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
		}, children)
	end
	local children = {
		Layout = Roact.createElement(
			"UIListLayout",
			{ Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }
		),
	}

	if props.Layout == "stacked" then
		for key, field in fields do
			children[key] = field
		end
	elseif props.Layout == "pair" then
		children["Version and realm"] =
			row({ ["Field Version"] = fields["Field Version"], ["Field Realm"] = fields["Field Realm"] }, 1)
		children["Field Name"] = fields["Field Name"]
	else
		children.Fields = row(fields, 1)
	end

	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, children)
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(InstallForm)
