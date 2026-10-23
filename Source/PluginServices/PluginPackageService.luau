local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)
local Console = require(script.Parent.Parent.Packages.Console)
local Promise = require(script.Parent.Parent.Packages.Promise)
local Signal = require(script.Parent.Parent.Packages.Signal)
local Trove = require(script.Parent.Parent.Packages.Trove)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginActionService = require(script.Parent.PluginActionService)
local PluginSerialiserService = require(script.Parent.PluginSerialiserService)
local PluginWallyApiService = require(script.Parent.PluginWallyApiService)

local describeRequestFailure = require(script.Parent.Parent.PluginUtilities.describeRequestFailure)
local packageIdFromFolderName = require(script.Parent.Parent.PluginUtilities.packageIdFromFolderName)
local parsePackageName = require(script.Parent.Parent.PluginUtilities.parsePackageName)
local parsePackageReq = require(script.Parent.Parent.PluginUtilities.parsePackageReq)
local pickDefaultVersion = require(script.Parent.Parent.PluginUtilities.pickDefaultVersion)
local planInstallation = require(script.Parent.Parent.PluginUtilities.planInstallation)
local readManifestSource = require(script.Parent.Parent.PluginUtilities.readManifestSource)
local resolvePackages = require(script.Parent.Parent.PluginUtilities.resolvePackages)
local toPascalCase = require(script.Parent.Parent.PluginUtilities.toPascalCase)
local writeManifestSource = require(script.Parent.Parent.PluginUtilities.writeManifestSource)

local INDEX_NAME = "_Plugin_Index"
local MANIFEST_NAME = "Manifest_DO_NOT_MODIFY"
local ROOT_ID = "place/root@0.0.0"
local REALMS = { "shared", "server" }
local MANIFEST_KEYS = { shared = "Dependencies", server = "ServerDependencies" }
local ROOT_KEYS = { shared = "dependencies", server = "serverDependencies" }
local ROOT_LINK_PATTERNS = {
	'^return require%(script%.Parent%._Plugin_Index%["([^"]+)"%]%["[^"]+"%]%)\n?$',
	'^return require%(game%.ReplicatedStorage%.Packages%._Plugin_Index%["([^"]+)"%]%["[^"]+"%]%)\n?$',
	'^return require%(game%.ServerStorage%.Packages%._Plugin_Index%["([^"]+)"%]%["[^"]+"%]%)\n?$',
}

local PluginPackageService = {}

PluginPackageService.Reporter = Console.new(`🍃 {script.Name}`)
PluginPackageService.Trove = Trove.new()
PluginPackageService.IndexWatch = PluginPackageService.Trove:Extend()
PluginPackageService.WatchGeneration = 0
PluginPackageService.Registry = PluginWallyApiService
PluginPackageService.Serialiser = PluginSerialiserService
PluginPackageService.Locations = { shared = ReplicatedStorage, server = ServerStorage }
PluginPackageService.Recorder = {
	Begin = function(name: string): string?
		return ChangeHistoryService:TryBeginRecording(name)
	end,
	Finish = function(recording: string, commit: boolean)
		ChangeHistoryService:FinishRecording(
			recording,
			if commit then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end,
}
PluginPackageService.ActiveOperation = nil :: string?

PluginPackageService.OnPackageAddedToIndex = Signal.new()
PluginPackageService.OnPackageRemovedFromIndex = Signal.new()
PluginPackageService.OnOperationProgress = Signal.new()

--[[
	Returns a failed Result carrying one InstallError.
]]
function PluginPackageService.Fail(_: PluginPackageService, kind: Types.ErrorKind, message: string, package: string?)
	return { ok = false, error = { kind = kind, message = message, package = package } }
end

--[[
	The index folder a root link written by the plugin points at, or nil for anything else. A root link is the
		plugin's when its source is one `return require(...)` into `_Plugin_Index`, from its own realm or from the other
		one; nothing else under `Packages` is ever changed.
]]
function PluginPackageService.ReadLinkTarget(_: PluginPackageService, instance: Instance): string?
	if not instance:IsA("ModuleScript") then
		return
	end

	for _, pattern in ROOT_LINK_PATTERNS do
		local folderName = string.match(instance.Source, pattern)

		if folderName then
			return folderName
		end
	end

	return
end

--[[
	Reads one realm's `Manifest_DO_NOT_MODIFY` as data, never running it. It can be edited by hand, so any shape but a
		PlaceManifest of requests refuses the operation and leaves the module as it is.
]]
function PluginPackageService.ReadManifest(self: PluginPackageService, module: Instance, realm: string)
	local parsed = readManifestSource(if module:IsA("ModuleScript") then module.Source else "")
	local refusal = `{module:GetFullName()} could not be read and was left as it is: `

	if not parsed.ok then
		return self:Fail("ManifestUnreadable", refusal .. parsed.error.message)
	end

	if parsed.value.FormatVersion ~= 1 then
		return self:Fail("ManifestUnreadable", `{refusal}FormatVersion is not 1`)
	end

	local requests = parsed.value[MANIFEST_KEYS[realm]] or {}

	for alias, text in requests do
		if not string.match(alias, "^[^%c]+$") or not parsePackageReq(text).ok then
			return self:Fail("ManifestUnreadable", `{refusal}entry '{alias}' is not a package requirement`)
		end
	end

	return { ok = true, value = requests }
end

--[[
	Reads what the place holds: each realm's `Packages` and `_Plugin_Index`, both manifests, and the installed
		package ids, taken from the index folder names as Wally takes them from its lockfile.
]]
function PluginPackageService.ReadState(self: PluginPackageService)
	local state: PlaceState = { folders = {}, indexes = {}, manifests = {}, installed = {} }

	for _, realm in REALMS do
		local folder = self.Locations[realm]:FindFirstChild("Packages")
		local index = folder and folder:FindFirstChild(INDEX_NAME)
		local manifestModule = index and index:FindFirstChild(MANIFEST_NAME)
		local read = if manifestModule then self:ReadManifest(manifestModule, realm) else { ok = true, value = {} }

		if folder and not folder:IsA("Folder") then
			return self:Fail("NameClash", `{folder:GetFullName()} exists and is not a Folder`)
		end

		if not read.ok then
			return read
		end

		state.folders[realm] = folder
		state.indexes[realm] = index
		state.manifests[realm] = read.value

		for _, child in if index then index:GetChildren() else {} do
			local id = packageIdFromFolderName(child.Name)

			if child:IsA("Folder") and id then
				state.installed[id] = true
			end
		end
	end

	return { ok = true, value = state }
end

--[[
	Builds the place's root manifest from both realms' requests, as Wally reads a project's wally.toml.
]]
function PluginPackageService.BuildRoot(self: PluginPackageService, manifests: { [string]: { [string]: string } })
	local root = {
		package = {
			name = { scope = "place", name = "root" },
			version = CargoSemver.Version.parse("0.0.0"),
			realm = "shared",
			registry = "",
		},
		dependencies = {},
		serverDependencies = {},
		devDependencies = {},
	}

	for _, realm in REALMS do
		for alias, text in manifests[realm] do
			local request = parsePackageReq(text)

			if not request.ok then
				return self:Fail("InvalidRequest", request.error.message, text)
			end

			root[ROOT_KEYS[realm]][alias] = request.value
		end
	end

	return { ok = true, value = root }
end

--[[
	Every root link name the plan writes must be free or already the plugin's.
]]
function PluginPackageService.CheckClashes(self: PluginPackageService, plan: Types.InstallPlan, state: PlaceState)
	for _, realm in REALMS do
		local folder = state.folders[realm]

		for alias in plan[realm].rootLinks do
			local existing = folder and folder:FindFirstChild(alias)

			if existing and not self:ReadLinkTarget(existing) then
				return self:Fail(
					"NameClash",
					`{existing:GetFullName()} already exists and was not written by the Wally plugin`
				)
			end
		end
	end

	return { ok = true, value = true }
end

--[[
	The requirement written when none is given: `^` and the version the registry website offers by default, read
		through the run's package source so the resolver does not fetch the package again.
]]
function PluginPackageService.FindDefaultRequirement(
	_: PluginPackageService,
	name: Types.PackageName,
	source: Types.PackageSource
): Types.Result<string>
	local fetched = source.versions(name)
	local versions = {}

	if not fetched.ok then
		return fetched
	end

	for _, manifest in fetched.value do
		table.insert(versions, tostring(manifest.package.version))
	end

	local default = pickDefaultVersion(versions)

	if not default.ok then
		return default
	end

	return { ok = true, value = `^{default.value}` }
end

--[[
	Downloads and builds every package the plan needs that the place does not hold yet, reporting progress as the
		downloads start and after each one. Every failure is collected before rejecting, so one report names every
		package that could not be installed.
]]
function PluginPackageService.BuildPackagesAsync(
	self: PluginPackageService,
	operation: string,
	plan: Types.InstallPlan,
	state: PlaceState,
	resolve: Types.Resolve
)
	return Promise.new(function(resolvePromise, reject)
		local built: { [string]: Instance } = {}
		local errors: { Types.InstallError } = {}
		local missing = {}

		for _, realm in REALMS do
			local index = state.indexes[realm]

			for folderName, id in plan[realm].packages do
				if not (index and index:FindFirstChild(folderName)) then
					table.insert(missing, { folderName = folderName, id = id })
				end
			end
		end

		if #missing > 0 then
			self.OnOperationProgress:Fire({ operation = operation, step = "downloading", done = 0, total = #missing })
		end

		for position, entry in missing do
			local id = entry.id
			local packageId = resolve.activated[id]
			local downloaded, zipOrFailure = self.Registry
				:DownloadPackageZipAsync(packageId.name.scope, packageId.name.name, tostring(packageId.version))
				:await()

			self.OnOperationProgress:Fire({
				operation = operation,
				step = "downloading",
				done = position,
				total = #missing,
			})

			if not downloaded then
				local reason = describeRequestFailure(zipOrFailure)

				table.insert(errors, {
					kind = "DownloadFailed",
					message = `{id} could not be downloaded: the registry answered {reason}`,
					package = id,
				})

				continue
			end

			local serialised = self.Serialiser:SerialiseZipIntoRobloxInstances(zipOrFailure, packageId.name.name)
			local failure = if serialised.ok then nil else serialised.error
			local location = if failure and failure.path ~= "" then `{failure.path}: ` else ""

			if failure then
				table.insert(errors, {
					kind = "BuildFailed",
					message = `{id} could not be built: {location}{failure.message}`,
					package = id,
				})

				continue
			end

			serialised.value.Name = packageId.name.name
			built[entry.folderName] = serialised.value
		end

		if #errors > 0 then
			self:DestroyBuilt(built)
			reject(errors)

			return
		end

		resolvePromise(built)
	end)
end

--[[
	Destroys every instance built for an operation that never reached the place.
]]
function PluginPackageService.DestroyBuilt(_: PluginPackageService, built: { [string]: Instance })
	for _, instance in built do
		instance:Destroy()
	end
end

--[[
	Puts a ModuleScript named `name` saying `source` under `parent`. One that already says the same is kept; one that
		says something else is replaced and unparented rather than rewritten, because Studio's undo brings back
		instances but not a Source a plugin wrote, and an undo must restore the old script with what it said.
]]
function PluginPackageService.WriteModule(_: PluginPackageService, parent: Instance, name: string, source: string)
	local existing = parent:FindFirstChild(name)

	if existing and existing:IsA("ModuleScript") and existing.Source == source then
		return
	end

	local module = Instance.new("ModuleScript")

	if existing then
		existing.Parent = nil
	end

	module.Name = name
	module.Source = source
	module.Parent = parent
end

--[[
	Writes the links one folder must hold and removes the link ModuleScripts it no longer needs. Inside a package
		folder every ModuleScript but the package itself is a link; inside `Packages` only the plugin's own root
		links are, so nothing else there is ever removed.
]]
function PluginPackageService.WriteLinks(
	self: PluginPackageService,
	parent: Instance,
	links: { [string]: string },
	packageName: string?
)
	for _, child in parent:GetChildren() do
		local isLink = child:IsA("ModuleScript") and child.Name ~= packageName
		local isOurs = if packageName then isLink else self:ReadLinkTarget(child)

		if isOurs and not links[child.Name] then
			child.Parent = nil
		end
	end

	for alias, source in links do
		self:WriteModule(parent, alias, source)
	end
end

--[[
	Changes the place to match the plan without yielding: creates the folders it needs, adds new packages, rewrites
		links, prunes what nothing needs, writes the manifests, and removes its own `_Plugin_Index` once it is empty, then
		its `Packages` if nothing else is in it. Removed instances are unparented, not destroyed, so a recorded undo
		can bring them back.
]]
function PluginPackageService.ApplyPlan(
	self: PluginPackageService,
	plan: Types.InstallPlan,
	built: { [string]: Instance },
	state: PlaceState,
	manifests: { [string]: { [string]: string } },
	resolve: Types.Resolve
)
	local counts = { added = 0, kept = 0, removed = 0 }

	for _, realm in REALMS do
		local realmPlan = plan[realm]
		local requests = manifests[realm]
		local needed = next(realmPlan.packages) or next(requests)
		local folder = state.folders[realm]
		local index = state.indexes[realm]

		if needed and not folder then
			folder = Instance.new("Folder")
			folder.Name = "Packages"
			folder.Parent = self.Locations[realm]
		end

		if needed and not index then
			index = Instance.new("Folder")
			index.Name = INDEX_NAME
			index.Parent = folder
		end

		for _, child in if index then index:GetChildren() else {} do
			if child:IsA("Folder") and not realmPlan.packages[child.Name] then
				child.Parent = nil
				counts.removed += 1
			end
		end

		for folderName, id in realmPlan.packages do
			local packageFolder = index:FindFirstChild(folderName)

			if packageFolder then
				counts.kept += 1
			else
				packageFolder = Instance.new("Folder")
				packageFolder.Name = folderName
				built[folderName].Parent = packageFolder
				packageFolder.Parent = index
				counts.added += 1
			end

			self:WriteLinks(packageFolder, realmPlan.packageLinks[folderName], resolve.activated[id].name.name)
		end

		if folder then
			self:WriteLinks(folder, realmPlan.rootLinks)
		end

		if index and next(requests) then
			self:WriteModule(
				index,
				MANIFEST_NAME,
				writeManifestSource({ FormatVersion = 1, [MANIFEST_KEYS[realm]] = requests })
			)
		elseif index then
			local manifestModule = index:FindFirstChild(MANIFEST_NAME)

			if manifestModule then
				manifestModule.Parent = nil
			end
		end

		if index and #index:GetChildren() == 0 then
			index.Parent = nil

			if folder and #folder:GetChildren() == 0 then
				folder.Parent = nil
			end
		end
	end

	return counts
end

--[[
	Runs one install or removal: reads the place, lets `change` edit the requests with the run's package source,
		resolves, plans, checks, downloads and builds, then commits inside one change-history recording, which makes the
		change one undo step. The place is untouched until the commit; an engine error during the commit cancels the
		recording, which undoes it. The indexes are not watched while the commit changes them.
]]
function PluginPackageService.RunAsync(
	self: PluginPackageService,
	operation: string,
	change: (
		manifests: { [string]: { [string]: string } },
		source: Types.PackageSource
	) -> Types.Result<{ [string]: { [string]: string } }>
)
	if self.ActiveOperation then
		return Promise.reject({ { kind = "Busy", message = `{self.ActiveOperation} is still running` } })
	end

	self.ActiveOperation = operation

	PluginActionService:StartAction("DownloadingPackage")

	return Promise.new(function(resolvePromise, reject)
		local state = self:ReadState()
		local source = self.Registry:CreatePackageSource()

		self.OnOperationProgress:Fire({ operation = operation, step = "resolving", done = 0, total = 0 })

		if not state.ok then
			reject({ state.error })

			return
		end

		local changed = change(state.value.manifests, source)
		local root = if changed.ok then self:BuildRoot(changed.value) else changed
		local resolved = if root.ok then resolvePackages(root.value, state.value.installed, source) else root
		local planned = if resolved.ok then planInstallation(resolved.value, ROOT_ID) else resolved
		local checked = if planned.ok then self:CheckClashes(planned.value, state.value) else planned

		if not checked.ok then
			reject({ checked.error })

			return
		end

		local builtOk, built = self:BuildPackagesAsync(operation, planned.value, state.value, resolved.value):await()

		if not builtOk then
			reject(built)

			return
		end

		local recording = self.Recorder.Begin(operation)

		if not recording then
			self:DestroyBuilt(built)
			reject({ { kind = "Busy", message = "Studio is recording another change; try again once it finishes" } })

			return
		end

		local freshState = self:ReadState()
		local rechecked = if freshState.ok then self:CheckClashes(planned.value, freshState.value) else freshState

		if not rechecked.ok then
			self.Recorder.Finish(recording, false)
			self:DestroyBuilt(built)
			reject({ rechecked.error })

			return
		end

		local downloads = 0

		for _ in built do
			downloads += 1
		end

		self.OnOperationProgress:Fire({ operation = operation, step = "writing", done = downloads, total = downloads })
		self.IndexWatch:Clean()

		local committed, countsOrFailure =
			pcall(self.ApplyPlan, self, planned.value, built, freshState.value, changed.value, resolved.value)

		self.Recorder.Finish(recording, committed)
		self:WatchIndexes()

		if not committed then
			self:DestroyBuilt(built)
			reject({
				{ kind = "CommitFailed", message = `writing to the place failed and was undone: {countsOrFailure}` },
			})

			return
		end

		local counts = countsOrFailure

		counts.resolve = resolved.value

		resolvePromise(counts)
	end):finally(function()
		self.ActiveOperation = nil

		PluginActionService:EndAction("DownloadingPackage")
	end)
end

--[[
	Prints every error of a failed operation through the reporter and rejects with the list. `Reporter:Error` raises,
		so it runs in its own thread, as `Runtime.server.luau` reports errors. A thrown error, rather than a list of
		InstallErrors, is shown as `Unexpected`.
]]
function PluginPackageService.ReportFailure(
	self: PluginPackageService,
	operation: string,
	errors: { Types.InstallError }
)
	local problems = if errors[1] then errors else { { kind = "Unexpected", message = tostring(errors) } }
	local lines = { `{operation} failed; the place was not changed.` }

	for _, problem in problems do
		table.insert(lines, `  {problem.kind}: {problem.message}`)
	end

	task.spawn(function()
		self.Reporter:Error(table.concat(lines, "\n"))
	end)

	return Promise.reject(problems)
end

--[[
	Installs a package into a realm as a root dependency of the place. `requirement` is the version part (`"^1.8.0"`);
		without one, the package's default version is requested with `^`. `alias` defaults to the package name in
		PascalCase.
]]
function PluginPackageService.InstallAsync(
	self: PluginPackageService,
	packageName: string,
	realm: string,
	requirement: string?,
	alias: string?
)
	local chosenAlias = alias or toPascalCase(string.match(packageName, "/(.*)$") or packageName)
	local operation = `Install of {packageName}`

	return self:RunAsync(operation, function(manifests, source)
		local name = parsePackageName(packageName)
		local otherRealm = if realm == "shared" then "server" else "shared"

		if not MANIFEST_KEYS[realm] then
			return self:Fail("InvalidRequest", `the realm must be "shared" or "server", not "{realm}"`)
		end

		if not name.ok then
			return name
		end

		if manifests[otherRealm][chosenAlias] then
			return self:Fail("NameClash", `{chosenAlias} is already installed in the {otherRealm} realm`)
		end

		local versionRequirement = if requirement
			then { ok = true, value = requirement }
			else self:FindDefaultRequirement(name.value, source)

		if not versionRequirement.ok then
			return versionRequirement
		end

		manifests[realm][chosenAlias] = `{packageName}@{versionRequirement.value}`

		return { ok = true, value = manifests }
	end):andThen(function(counts)
		local sharedLinks = counts.resolve.sharedDependencies[ROOT_ID] or {}
		local serverLinks = counts.resolve.serverDependencies[ROOT_ID] or {}
		local id = sharedLinks[chosenAlias] or serverLinks[chosenAlias]
		local packages =
			self.Locations[if sharedLinks[chosenAlias] then "shared" else "server"]:FindFirstChild("Packages")
		local summary = {
			added = counts.added,
			kept = counts.kept,
			removed = counts.removed,
			id = id,
			rootLink = packages and packages:FindFirstChild(chosenAlias),
		}

		self.Reporter:Log(
			`Installed {id} as {chosenAlias}: {counts.added + counts.kept} packages ({counts.added} added, {counts.kept} already present).`
		)
		self.OnPackageAddedToIndex:FireDeferred(summary)

		return summary
	end, function(errors)
		return self:ReportFailure(operation, errors)
	end)
end

--[[
	Removes a root dependency from a realm, then prunes every package nothing else needs.
]]
function PluginPackageService.RemoveAsync(self: PluginPackageService, alias: string, realm: string)
	local operation = `Removal of {alias}`

	return self:RunAsync(operation, function(manifests)
		if not MANIFEST_KEYS[realm] or not manifests[realm][alias] then
			return self:Fail("InvalidRequest", `{alias} is not installed in the {realm} realm`)
		end

		manifests[realm][alias] = nil

		return { ok = true, value = manifests }
	end):andThen(function(counts)
		local summary = { added = counts.added, kept = counts.kept, removed = counts.removed }

		self.Reporter:Log(`Removed {alias}: {counts.removed} removed, {counts.kept} still installed.`)
		self.OnPackageRemovedFromIndex:FireDeferred(summary)

		return summary
	end, function(errors)
		return self:ReportFailure(operation, errors)
	end)
end

--[[
	Lists the place's root dependencies, each with the exact id its root link points at. A request's link is looked for
		in its own realm's Packages first, then the other's, because Wally links a server request for a package the
		place already shares from the shared Packages.
]]
function PluginPackageService.GetInstalled(self: PluginPackageService): { Types.InstalledPackage }
	local state = self:ReadState()
	local installed = {}

	if not state.ok then
		self.Reporter:Warn(`The installed packages could not be listed: {state.error.message}`)

		return installed
	end

	for _, realm in REALMS do
		local folder = state.value.folders[realm]
		local otherFolder = state.value.folders[if realm == "shared" then "server" else "shared"]

		for alias, requirement in state.value.manifests[realm] do
			local link = (folder and folder:FindFirstChild(alias))
				or (otherFolder and otherFolder:FindFirstChild(alias))
			local folderName = if link then self:ReadLinkTarget(link) else nil
			local linkedId = if folderName then packageIdFromFolderName(folderName) else nil

			table.insert(installed, {
				alias = alias,
				realm = realm,
				requirement = requirement,
				id = linkedId or requirement,
			})
		end
	end

	table.sort(installed, function(left, right)
		return left.alias < right.alias
	end)

	return installed
end

--[[
	Watches each realm's `_Plugin_Index` in place of the last watch, so one taken from the place by anything but the
		plugin is reported. The plugin stops watching while it commits, and an undo or redo starts a new watch before a
		removal it made is reported, which leaves outside removals such as Rojo live sync replacing `Packages` with the
		folder on disk.
]]
function PluginPackageService.WatchIndexes(self: PluginPackageService)
	local generation = self.WatchGeneration + 1

	self.WatchGeneration = generation
	self.IndexWatch:Clean()

	for _, realm in REALMS do
		local location = self.Locations[realm]
		local folder = location:FindFirstChild("Packages")
		local index = folder and folder:FindFirstChild(INDEX_NAME)

		if index then
			self:WatchIndex(location, index, generation)
		end
	end
end

--[[
	Warns once `index` leaves `location`, unless a newer watch has started by the time the removal is read, and tells
		whoever lists the installed packages that they changed.
]]
function PluginPackageService.WatchIndex(
	self: PluginPackageService,
	location: Instance,
	index: Instance,
	generation: number
)
	local path = index:GetFullName()
	local packageCount = 0

	for _, child in index:GetChildren() do
		if child:IsA("Folder") and packageIdFromFolderName(child.Name) then
			packageCount += 1
		end
	end

	local lost = if packageCount == 1
		then "the package installed in it is gone"
		else `the {packageCount} packages installed in it are gone`
	local warning =
		`{path} was removed by something other than the Wally plugin, so {lost}. Rojo live sync does this when its project syncs Packages from disk: install those packages with the Wally CLI, or leave Packages out of the Rojo project.`

	self.IndexWatch:Add(location.DescendantRemoving:Connect(function(descendant: Instance)
		if descendant ~= index then
			return
		end

		task.defer(function()
			if self.WatchGeneration ~= generation then
				return
			end

			self.Reporter:Warn(warning)
			self.OnPackageRemovedFromIndex:FireDeferred({
				added = 0,
				kept = 0,
				removed = packageCount,
				lostIndex = path,
				warning = warning,
			})
		end)
	end))
end

--[[
	Watches the indexes the place opened with, and again after every undo and redo, which can bring one back or take
		one away.
]]
function PluginPackageService.OnStart(self: PluginPackageService)
	self:WatchIndexes()
	self.Trove:Add(ChangeHistoryService.OnUndo:Connect(function()
		self:WatchIndexes()
	end))
	self.Trove:Add(ChangeHistoryService.OnRedo:Connect(function()
		self:WatchIndexes()
	end))
end

--[[
	Stops every watch.
]]
function PluginPackageService.OnStop(self: PluginPackageService)
	self.Trove:Destroy()
end

type PlaceState = {
	folders: { [string]: Instance? },
	indexes: { [string]: Instance? },
	manifests: { [string]: { [string]: string } },
	installed: { [string]: true },
}

export type PluginPackageService = typeof(PluginPackageService)

return PluginPackageService
