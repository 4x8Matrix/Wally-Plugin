local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local Console = require(script.Parent.Parent.Packages.Console)
local Roact = require(script.Parent.Parent.Packages.Roact)
local RoactRodux = require(script.Parent.Parent.Packages.RoactRodux)
local Sift = require(script.Parent.Parent.Packages.Sift)
local Trove = require(script.Parent.Parent.Packages.Trove)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginPackageService = require(script.Parent.PluginPackageService)
local PluginWallyApiService = require(script.Parent.PluginWallyApiService)
local RoactApp = require(script.Parent.Parent.PluginInterface)
local RoduxStore = require(script.Parent.Parent.PluginInterface.Store)

local describeRequestFailure = require(script.Parent.Parent.PluginUtilities.describeRequestFailure)
local fieldForInstallError = require(script.Parent.Parent.PluginUtilities.fieldForInstallError)
local findInstalled = require(script.Parent.Parent.PluginUtilities.findInstalled)
local formatPackageReq = require(script.Parent.Parent.PluginUtilities.formatPackageReq)
local isNewerVersion = require(script.Parent.Parent.PluginUtilities.isNewerVersion)
local pickDefaultVersion = require(script.Parent.Parent.PluginUtilities.pickDefaultVersion)
local readSearchResults = require(script.Parent.Parent.PluginUtilities.readSearchResults)
local requirementFor = require(script.Parent.Parent.PluginUtilities.requirementFor)
local selectionKey = require(script.Parent.Parent.PluginUtilities.selectionKey)
local sortVersions = require(script.Parent.Parent.PluginUtilities.sortVersions)
local toPascalCase = require(script.Parent.Parent.PluginUtilities.toPascalCase)

local PluginInterfaceService = {}

PluginInterfaceService.Reporter = Console.new(`🌟 {script.Name}`)
PluginInterfaceService.Trove = Trove.new()
PluginInterfaceService.Store = RoduxStore
PluginInterfaceService.Registry = PluginWallyApiService
PluginInterfaceService.Packages = PluginPackageService
PluginInterfaceService.History = ChangeHistoryService
PluginInterfaceService.Selection = Selection
PluginInterfaceService.SearchDelay = 0.25
PluginInterfaceService.SearchToken = 0
PluginInterfaceService.QueryThread = nil :: thread?
PluginInterfaceService.RoactHandle = nil

function PluginInterfaceService.CreateRoduxEvent(
	_: PluginInterfaceService,
	eventName: string,
	eventData: { [any]: any }
)
	eventData["type"] = eventName

	return eventData
end

--[[
	Dispatches one action to the interface's store.
]]
function PluginInterfaceService.Dispatch(self: PluginInterfaceService, eventName: string, eventData: { [any]: any })
	self.Store:dispatch(self:CreateRoduxEvent(eventName, eventData))
end

--[[
	Queries the registry `seconds` after the last keystroke, so typing sends one request when it stops. An answer that
		arrives after a newer search started is dropped.
]]
function PluginInterfaceService.QueryIn(self: PluginInterfaceService, seconds: number, textInput: string)
	local token = self.SearchToken + 1

	self.SearchToken = token

	if self.QueryThread then
		task.cancel(self.QueryThread)
	end

	self.QueryThread = task.delay(seconds, function()
		self.QueryThread = nil

		self.Registry
			:QueryWallyApiAsync(textInput)
			:andThen(function(packages)
				if token == self.SearchToken then
					self:Dispatch("setSearch", { search = { status = "done", results = readSearchResults(packages) } })
				end
			end)
			:catch(function(failure)
				if token == self.SearchToken then
					self:Dispatch("setSearch", {
						search = { status = "failed", results = {}, message = describeRequestFailure(failure) },
					})
				end
			end)
	end)
end

--[[
	Records what was typed and searches for it after `seconds` (the typing delay unless given), or clears the results
		and drops the pending search when the field is empty. Earlier results stay on screen while the new search runs.
]]
function PluginInterfaceService.SearchFor(self: PluginInterfaceService, textInput: string, seconds: number?)
	local results = self.Store:getState().search.results

	self:Dispatch("setQuery", { query = textInput })

	if textInput == "" then
		if self.QueryThread then
			task.cancel(self.QueryThread)
			self.QueryThread = nil
		end

		self.SearchToken += 1
		self:Dispatch("setSearch", { search = { status = "idle", results = {} } })

		return
	end

	self:Dispatch("setSearch", { search = { status = "searching", results = results } })
	self:QueryIn(seconds or self.SearchDelay, textInput)
end

--[[
	Reads every version of a package for the install surface: newest first, the registry website's default as
		latest, each version's realm and the dependencies it brings. Unless `keepVersion` is set, the form takes the
		latest version and, for a server-only package, the Server realm.
]]
function PluginInterfaceService.LoadDetail(
	self: PluginInterfaceService,
	scope: string,
	name: string,
	keepVersion: boolean
)
	local token = selectionKey(self.Store:getState().selection)

	self:Dispatch("setDetail", { detail = { status = "loading", versions = {}, realms = {} } })

	self.Registry
		:GetPackageMetadataAsync(scope, name)
		:andThen(function(manifests)
			local state = self.Store:getState()
			local versions = {}
			local realms = {}
			local dependencies = {}

			if selectionKey(state.selection) ~= token then
				return
			end

			for _, manifest in manifests do
				local version = tostring(manifest.package.version)
				local brings = {}

				for _, requests in { manifest.dependencies, manifest.serverDependencies } do
					for alias, request in requests or {} do
						table.insert(brings, `{alias} = {formatPackageReq(request)}`)
					end
				end

				table.sort(brings)
				table.insert(versions, version)
				realms[version] = manifest.package.realm
				dependencies[version] = brings
			end

			local latest = pickDefaultVersion(versions)
			local chosen = if latest.ok then latest.value else nil

			self:Dispatch("setDetail", {
				detail = {
					status = "done",
					versions = sortVersions(versions),
					latest = chosen,
					realms = realms,
					dependencies = dependencies,
				},
			})

			if not keepVersion and chosen then
				self:Dispatch("setForm", {
					form = {
						version = chosen,
						realm = if realms[chosen] == "server" then "server" else state.form.realm,
					},
				})
			end
		end)
		:catch(function(failure)
			if selectionKey(self.Store:getState().selection) == token then
				self:Dispatch("setDetail", {
					detail = {
						status = "failed",
						versions = {},
						realms = {},
						message = failure.message or tostring(failure),
					},
				})
			end
		end)
end

--[[
	Opens the install surface on a registry result, or closes it when the result is already open.
]]
function PluginInterfaceService.SelectResult(self: PluginInterfaceService, result: { [string]: any })
	local selection = { kind = "result", scope = result.scope, name = result.name }

	if selectionKey(selection) == selectionKey(self.Store:getState().selection) then
		self:ClearSelection()

		return
	end

	self:Dispatch("setSelection", { selection = selection })
	self:Dispatch(
		"setForm",
		{ form = { alias = toPascalCase(result.name), realm = "shared", version = result.version } }
	)
	self:LoadDetail(result.scope, result.name, false)
end

--[[
	Opens the install surface on an installed package, keeping its realm, alias and resolved version so the version
		picker offers an update.
]]
function PluginInterfaceService.SelectInstalled(self: PluginInterfaceService, package: { [string]: any })
	local selection = { kind = "installed", alias = package.alias, realm = package.realm }

	if selectionKey(selection) == selectionKey(self.Store:getState().selection) then
		self:ClearSelection()

		return
	end

	self:Dispatch("setSelection", { selection = selection })
	self:Dispatch("setForm", { form = { alias = package.alias, realm = package.realm, version = package.version } })
	self:LoadDetail(package.scope, package.name, true)
end

--[[
	Closes the install surface.
]]
function PluginInterfaceService.ClearSelection(self: PluginInterfaceService)
	self:Dispatch("setSelection", { selection = nil })
end

--[[
	Applies an edit to the form and clears its errors. Choosing a server-only version moves the realm to Server.
]]
function PluginInterfaceService.ChangeForm(self: PluginInterfaceService, changes: { [string]: any })
	local realms = self.Store:getState().detail.realms or {}
	local edit = Sift.Dictionary.merge(changes, { errors = {} })

	if changes.version and realms[changes.version] == "server" then
		edit.realm = "server"
	end

	self:Dispatch("setForm", { form = edit })
end

--[[
	Sorts an operation's problems under the form fields they concern, keeping the rest as general problems.
]]
function PluginInterfaceService.SortProblems(
	_: PluginInterfaceService,
	problems: { Types.InstallError }
): { [string]: any }
	local errors = { general = {} }

	for _, problem in problems do
		local field = fieldForInstallError(problem)

		if field == "general" then
			table.insert(errors.general, problem.message)
		elseif not errors[field] then
			errors[field] = problem.message
		end
	end

	return errors
end

--[[
	Ends a failed operation: the notice bar says how many problems stopped it, and they go under their fields when the
		surface is still open on what the operation was for. A rejection that is not a list of problems, such as an
		error thrown along the way, counts as one unexpected problem.
]]
function PluginInterfaceService.ReportProblems(
	self: PluginInterfaceService,
	verb: string,
	subject: string,
	target: string,
	failure: any
)
	local problems = if failure[1] then failure else { { kind = "Unexpected", message = tostring(failure) } }
	local count = #problems

	self:Dispatch("setOperation", { operation = nil })

	if selectionKey(self.Store:getState().selection) == target then
		self:Dispatch("setForm", { form = { errors = self:SortProblems(problems) } })
	end

	self:Dispatch("setNotice", {
		notice = {
			kind = "failed",
			message = if count == 1
				then `One problem stopped the {verb} of {subject}`
				else `{count} problems stopped the {verb} of {subject}`,
		},
	})
end

--[[
	Closes the install surface after an operation succeeds, unless it was opened on something else while it ran.
]]
function PluginInterfaceService.CloseFinished(self: PluginInterfaceService, target: string)
	if selectionKey(self.Store:getState().selection) == target then
		self:ClearSelection()
	end
end

--[[
	Installs what the form describes: a new package from a result, or a new version of an installed one, at exactly
		the version chosen. Refused while another operation runs.
]]
function PluginInterfaceService.Install(self: PluginInterfaceService)
	local state = self.Store:getState()
	local selection = state.selection
	local form = state.form
	local installed = findInstalled(state.installed, selection)
	local updating = if installed then true else false
	local verb = if updating then "update" else "install"
	local target = selectionKey(selection)

	if state.operation then
		return
	end

	if not selection or not form.version then
		self.Reporter:Warn("Install was clicked with no package or no version chosen")

		return
	end

	if selection.kind == "installed" and not installed then
		return
	end

	local packageName = if installed then `{installed.scope}/{installed.name}` else `{selection.scope}/{selection.name}`

	self:Dispatch("setNotice", { notice = nil })
	self:Dispatch("setOperation", {
		operation = { kind = verb, target = target, step = "resolving", done = 0, total = 0 },
	})

	self.Packages
		:InstallAsync(packageName, form.realm, requirementFor(form.version, state.detail.versions), form.alias)
		:andThen(function(summary)
			local version = string.match(summary.id or "", "@(.+)$") or form.version
			local message = if not updating
				then `Installed {form.alias} {version}`
				elseif isNewerVersion(version, installed.version) then `Updated {form.alias} to {version}`
				else `Rolled {form.alias} back to {version}`

			self:Dispatch("setOperation", { operation = nil })
			self:Dispatch("setNotice", {
				notice = {
					kind = "installed",
					message = message,
					rootLink = summary.rootLink,
				},
			})
			self:CloseFinished(target)
			self:RefreshInstalled()
		end)
		:catch(function(failure)
			self:ReportProblems(verb, form.alias, target, failure)
		end)
end

--[[
	Removes the installed package the surface is open on, pruning what nothing else needs.
]]
function PluginInterfaceService.Remove(self: PluginInterfaceService)
	local state = self.Store:getState()
	local selection = state.selection
	local target = selectionKey(selection)

	if state.operation then
		return
	end

	if not selection or selection.kind ~= "installed" then
		self.Reporter:Warn("Remove was clicked with no installed package chosen")

		return
	end

	self:Dispatch("setNotice", { notice = nil })
	self:Dispatch("setOperation", {
		operation = { kind = "remove", target = target, step = "resolving", done = 0, total = 0 },
	})

	self.Packages
		:RemoveAsync(selection.alias, selection.realm)
		:andThen(function()
			self:Dispatch("setOperation", { operation = nil })
			self:Dispatch("setNotice", { notice = { kind = "removed", message = `Removed {selection.alias}` } })
			self:CloseFinished(target)
			self:RefreshInstalled()
		end)
		:catch(function(failure)
			self:ReportProblems("removal", selection.alias, target, failure)
		end)
end

--[[
	Follows the backend's progress on the running operation.
]]
function PluginInterfaceService.TrackProgress(self: PluginInterfaceService, progress: Types.Progress)
	local operation = self.Store:getState().operation

	if not operation then
		return
	end

	self:Dispatch("setOperation", {
		operation = Sift.Dictionary.merge(
			operation,
			{ step = progress.step, done = progress.done, total = progress.total }
		),
	})
end

--[[
	Lists the place's installed packages, each with its id split into scope, name and resolved version, and the
		requirement the place asks for.
]]
function PluginInterfaceService.RefreshInstalled(self: PluginInterfaceService)
	local installed = {}

	for _, row in self.Packages:GetInstalled() do
		local scope, name, version = string.match(row.id, "^([^/]+)/([^@]+)@(.+)$")

		table.insert(installed, {
			alias = row.alias,
			realm = row.realm,
			scope = scope or "",
			name = name or row.alias,
			version = version or "",
			requirement = string.match(row.requirement, "@(.+)$") or row.requirement,
		})
	end

	self:Dispatch("setInstalled", { installed = installed })
end

--[[
	Selects the root link the install notice names in the Explorer, which the old Download as Module menu did.
]]
function PluginInterfaceService.ShowInExplorer(self: PluginInterfaceService)
	local notice = self.Store:getState().notice
	local rootLink = notice and notice.rootLink

	if rootLink and rootLink.Parent then
		self.Selection:Set({ rootLink })
	end
end

--[[
	Undoes the last change through Studio's history, which reverts an install or a removal in one step.
]]
function PluginInterfaceService.Undo(self: PluginInterfaceService)
	self.History:Undo()
	self:Dispatch("setNotice", { notice = nil })
end

--[[
	Refreshes the list after a removal, and when an index was lost outside the plugin, shows the backend's warning in
		the notice bar.
]]
function PluginInterfaceService.OnIndexRemoved(self: PluginInterfaceService, summary: { [string]: any })
	self:RefreshInstalled()

	if summary.lostIndex then
		self:Dispatch("setNotice", { notice = { kind = "lostIndex", message = summary.warning } })
	end
end

--[[
	Installs every UI callback into the store, each a thin call into this service.
]]
function PluginInterfaceService.UpdateRoduxCallbacks(self: PluginInterfaceService)
	self:Dispatch("setCallbacks", {
		callbacks = {
			onSearchTextUpdated = function(textInput: string)
				self:SearchFor(textInput)
			end,
			onSearchSubmitted = function(textInput: string)
				self:SearchFor(textInput, 0)
			end,
			onRetrySearch = function()
				self:SearchFor(self.Store:getState().query)
			end,
			onTabSelected = function(tab: string)
				self:ClearSelection()
				self:Dispatch("setTab", { tab = tab })
			end,
			onResultSelected = function(result)
				self:SelectResult(result)
			end,
			onInstalledSelected = function(package)
				self:SelectInstalled(package)
			end,
			onSelectionCleared = function()
				self:ClearSelection()
			end,
			onFormChanged = function(changes)
				self:ChangeForm(changes)
			end,
			onInstallClicked = function()
				self:Install()
			end,
			onRemoveClicked = function()
				self:Remove()
			end,
			onShowInExplorer = function()
				self:ShowInExplorer()
			end,
			onUndo = function()
				self:Undo()
			end,
			onNoticeDismissed = function()
				self:Dispatch("setNotice", { notice = nil })
			end,
		},
	})
end

function PluginInterfaceService.MountInterfaceOnto(self: PluginInterfaceService, instance: Instance)
	self.RoactHandle = Roact.mount(
		Roact.createElement(RoactRodux.StoreProvider, { store = self.Store }, {
			MainInterface = Roact.createElement(RoactApp),
		}),
		instance
	)
end

function PluginInterfaceService.UnmountInterface(self: PluginInterfaceService)
	if self.RoactHandle then
		Roact.unmount(self.RoactHandle)
	end

	self.RoactHandle = nil
end

--[[
	Installs the callbacks, lists what is installed, and follows the backend: index changes, progress, and Studio's
		undo and redo.
]]
function PluginInterfaceService.OnStart(self: PluginInterfaceService)
	self:UpdateRoduxCallbacks()
	self:RefreshInstalled()

	self.Trove:Add(self.Packages.OnPackageAddedToIndex:Connect(function()
		self:RefreshInstalled()
	end))
	self.Trove:Add(self.Packages.OnPackageRemovedFromIndex:Connect(function(summary)
		self:OnIndexRemoved(summary)
	end))
	self.Trove:Add(self.Packages.OnOperationProgress:Connect(function(progress)
		self:TrackProgress(progress)
	end))
	self.Trove:Add(self.History.OnUndo:Connect(function()
		self:RefreshInstalled()
	end))
	self.Trove:Add(self.History.OnRedo:Connect(function()
		self:RefreshInstalled()
	end))
end

function PluginInterfaceService.OnStop(self: PluginInterfaceService)
	if self.QueryThread then
		task.cancel(self.QueryThread)
		self.QueryThread = nil
	end

	self.Trove:Destroy()
end

export type PluginInterfaceService = typeof(PluginInterfaceService)

return PluginInterfaceService
