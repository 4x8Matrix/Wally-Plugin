local Roact = require(script.Parent.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Parent.Packages.RoactRodux)

local Link = require(script.Parent.Common.Link)
local PrimaryButton = require(script.Parent.Common.PrimaryButton)

local describeStep = require(script.Parent.Parent.Parent.PluginUtilities.describeStep)
local findInstalled = require(script.Parent.Parent.Parent.PluginUtilities.findInstalled)
local isNewerVersion = require(script.Parent.Parent.Parent.PluginUtilities.isNewerVersion)
local selectionKey = require(script.Parent.Parent.Parent.PluginUtilities.selectionKey)

local InstallAction = Roact.Component:extend("InstallAction")

InstallAction.defaultProps = { Height = 36, LayoutOrder = 0 }

--[[
	How far along an operation is: resolving is the first sixth, downloads fill most of the bar, writing nearly ends it.
]]
local function measureStep(operation): number
	if operation.step == "downloading" and operation.total > 0 then
		return 0.15 + 0.7 * operation.done / operation.total
	end

	return if operation.step == "writing" then 0.95 else 0.15
end

--[[
	The button's label and state for the selection: install a result, update an installed package or roll it back to
		an older version, show progress for the running operation, or say why it cannot run, such as the version
		chosen being the one installed or an installed package that has since gone.
]]
function InstallAction:describeButton()
	local store = self.props.store
	local selection = store.selection
	local form = store.form
	local operation = store.operation
	local package = findInstalled(store.installed, selection)

	if operation and operation.target == selectionKey(selection) then
		return { text = describeStep(operation), progress = measureStep(operation) }
	end

	if operation then
		return { text = "Another install is running", disabled = true }
	end

	if selection and selection.kind == "installed" and not package then
		return { text = "No longer installed", disabled = true }
	end

	if store.detail.status ~= "done" or not form.version then
		return { text = if package then "Update" else "Install", disabled = true }
	end

	if package and form.version == package.version then
		return { text = `{form.version} is installed`, disabled = true }
	end

	if package then
		return {
			text = if isNewerVersion(form.version, package.version)
				then `Update to {form.version}`
				else `Roll back to {form.version}`,
		}
	end

	if form.alias == "" then
		return { text = "Give it a name in Packages", disabled = true }
	end

	return { text = `Install {form.alias} {form.version}` }
end

--[[
	The surface's action: the primary button, and Remove for an installed package.
]]
function InstallAction:render()
	local props = self.props
	local store = props.store
	local button = self:describeButton()
	local installed = store.selection and store.selection.kind == "installed"

	return Roact.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, {
		Layout = Roact.createElement("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		["Install button"] = Roact.createElement(PrimaryButton, {
			Text = button.text,
			Disabled = button.disabled or false,
			Progress = button.progress,
			Height = props.Height,
			LayoutOrder = 2,
			OnActivated = store.onInstallClicked,
		}),
		Remove = if installed
			then Roact.createElement(Link, {
				Text = `Remove {store.selection.alias}`,
				Role = "error",
				Disabled = if store.operation then true else false,
				LayoutOrder = 3,
				OnActivated = store.onRemoveClicked,
			})
			else nil,
	})
end

return RoactRodux.connect(function(state)
	return { store = state }
end)(InstallAction)
