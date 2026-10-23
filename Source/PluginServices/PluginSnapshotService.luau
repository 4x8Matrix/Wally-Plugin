local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginMetaService = require(script.Parent.PluginMetaService)
local PluginModelService = require(script.Parent.PluginModelService)
local PluginProjectService = require(script.Parent.PluginProjectService)
local PluginReflectionService = require(script.Parent.PluginReflectionService)
local VirtualFileSystem = require(script.Parent.Parent.PluginClasses.VirtualFileSystem)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)
local compileGlob = require(script.Parent.Parent.PluginUtilities.compileGlob)
local decodeFileContents = require(script.Parent.Parent.PluginUtilities.decodeFileContents)
local fileNameOfPath = require(script.Parent.Parent.PluginUtilities.fileNameOfPath)
local instanceNameForFile = require(script.Parent.Parent.PluginUtilities.instanceNameForFile)
local isPathIgnored = require(script.Parent.Parent.PluginUtilities.isPathIgnored)
local joinPath = require(script.Parent.Parent.PluginUtilities.joinPath)

local DEFAULT_SYNC_RULES = {
	{ pattern = "*.server.lua", use = "serverScript", suffix = ".server.lua" },
	{ pattern = "*.server.luau", use = "serverScript", suffix = ".server.luau" },
	{ pattern = "*.client.lua", use = "clientScript", suffix = ".client.lua" },
	{ pattern = "*.client.luau", use = "clientScript", suffix = ".client.luau" },
	{ pattern = "*.plugin.lua", use = "pluginScript", suffix = ".plugin.lua" },
	{ pattern = "*.plugin.luau", use = "pluginScript", suffix = ".plugin.luau" },
	{ pattern = "*.{lua,luau}", use = "moduleScript" },
	{ pattern = "*.project.json", use = "project", suffix = ".project.json" },
	{ pattern = "*.project.jsonc", use = "project", suffix = ".project.jsonc" },
	{ pattern = "*.model.json", use = "jsonModel", suffix = ".model.json" },
	{ pattern = "*.model.jsonc", use = "jsonModel", suffix = ".model.jsonc" },
	{ pattern = "*.json", use = "json", suffix = ".json", exclude = "*.meta.json" },
	{ pattern = "*.jsonc", use = "json", suffix = ".jsonc", exclude = "*.meta.jsonc" },
	{ pattern = "*.toml", use = "toml" },
	{ pattern = "*.csv", use = "csv" },
	{ pattern = "*.txt", use = "text" },
	{ pattern = "*.rbxmx", use = "rbxmx" },
	{ pattern = "*.rbxm", use = "rbxm" },
	{ pattern = "*.{yml,yaml}", use = "yaml" },
}
local DIRECTORY_INITS = {
	{ name = "default.project.json", use = "project" },
	{ name = "default.project.jsonc", use = "project" },
	{ name = "init.luau", use = "moduleScript" },
	{ name = "init.lua", use = "moduleScript" },
	{ name = "init.server.luau", use = "serverScript" },
	{ name = "init.server.lua", use = "serverScript" },
	{ name = "init.client.luau", use = "clientScript" },
	{ name = "init.client.lua", use = "clientScript" },
	{ name = "init.plugin.lua", use = "pluginScript" },
	{ name = "init.plugin.luau", use = "pluginScript" },
	{ name = "init.csv", use = "csv" },
}

local PluginSnapshotService = {}

PluginSnapshotService.DefaultSyncRules = {} :: { Types.SyncRule }
PluginSnapshotService.InitFileNames = {} :: { [string]: true }

for _, rule in DEFAULT_SYNC_RULES do
	table.insert(PluginSnapshotService.DefaultSyncRules, {
		matches = compileGlob(rule.pattern).value,
		excludes = if rule.exclude then compileGlob(rule.exclude).value else nil,
		use = rule.use,
		suffix = rule.suffix,
	})
end

for _, init in DIRECTORY_INITS do
	if init.use ~= "project" then
		PluginSnapshotService.InitFileNames[init.name] = true
	end
end

--[[
	The context a package is built in when no project sets one: no sync rules, no ignore rules, legacy scripts.
]]
function PluginSnapshotService.DefaultContext(_: PluginSnapshotService): Types.SnapshotContext
	return { syncRules = {}, ignoreRules = {}, emitLegacyScripts = true }
end

--[[
	Snapshots a package's files as Rojo 7.7.1 builds its folder in Wally's layout, a directory entry named after
		the package (spec, Constraints): the zip root through SnapshotPath in the default context, with the root
		named `name` whatever a project at the root calls it. A package that builds nothing is refused, and so is
		one holding a class a plugin cannot create, where Rojo writes it unchecked (the spec's deviation). That
		check runs last, over what is left once DataModels are left out, so Rojo's own refusals anywhere come first,
		and a class standing inside a DataModel that Studio's loader drops is never refused. A DataModel at the
		root is refused this way, its loader dropping the whole package.
]]
function PluginSnapshotService.SnapshotPackage(
	self: PluginSnapshotService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	name: string
): Types.BuildResult<Types.Snapshot>
	local snapshot = self:SnapshotPath(fileSystem, "", self:DefaultContext(), name)

	if not snapshot.ok then
		return snapshot
	end

	if not snapshot.value then
		return buildError("", "the package builds no instance")
	end

	local uncreatable = self:FindUncreatable(snapshot.value)

	if uncreatable then
		PluginModelService:DestroyModels({ snapshot.value })

		return buildError(uncreatable.path, `Class {uncreatable.className} cannot be created by a plugin`)
	end

	snapshot.value.name = name

	return snapshot
end

-- seam: NotAClass, Workspace and Players in a Folder refuse; Studio drops them; upgrade trigger: one in a package
-- seam: StarterPlayerScripts and PackageLink in a Folder refuse; Studio loads them; upgrade trigger: one in a package
-- seam: a Player in a dropped DataModel passes; Studio cannot load Rojo's build; upgrade trigger: one in a package
--[[
	The first snapshot, root first and then each child in order, whose class a plugin cannot create. A snapshot
		holding a loaded model of its own class is already an instance, so only what was added under it is looked
		at; one whose class takes over a model of another class is created, so its class is checked too.
]]
function PluginSnapshotService.FindUncreatable(self: PluginSnapshotService, snapshot: Types.Snapshot): Types.Snapshot?
	local isLoaded = if snapshot.model then snapshot.model.ClassName == snapshot.className else false

	if not isLoaded and not PluginReflectionService:ClassExists(snapshot.className) then
		return snapshot
	end

	for _, child in snapshot.children do
		local found = self:FindUncreatable(child)

		if found then
			return found
		end
	end

	return
end

--[[
	Snapshots one path as Rojo 7.7.1's `snapshot_from_vfs` does (R1.1): nothing for a missing path; a directory
		by its project or init file, else as a Folder; nothing for a file named like an init file; any other file
		by the first user sync rule that matches its path, else the first default rule, else nothing. `name` is
		the name of the entry at `path`, its file name unless given, which the zip root needs.
]]
function PluginSnapshotService.SnapshotPath(
	self: PluginSnapshotService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	context: Types.SnapshotContext,
	name: string?
): Types.BuildResult<Types.Snapshot?>
	local entryName = name or fileNameOfPath(path)
	local isFile = fileSystem:IsFile(path)
	local rule = if isFile then self:FindSyncRule(context, path) else nil

	if fileSystem:IsDirectory(path) then
		return self:SnapshotDirectory(fileSystem, path, context, entryName)
	end

	if not rule or self.InitFileNames[entryName] then
		return { ok = true }
	end

	return self:SnapshotFile(fileSystem, path, context, rule.use, instanceNameForFile(entryName, rule.suffix))
end

--[[
	The first of the context's sync rules matching the path, else the first default rule, each vetoed by its
		`exclude` glob. Every rule is handed the path from the zip root, so a project's rules strip the project's
		folder before matching, as Rojo matches them relative to it.
]]
function PluginSnapshotService.FindSyncRule(
	self: PluginSnapshotService,
	context: Types.SnapshotContext,
	path: string
): Types.SyncRule?
	for _, rules in { context.syncRules, self.DefaultSyncRules } do
		for _, rule in rules do
			if rule.matches(path) and not (rule.excludes and rule.excludes(path)) then
				return rule
			end
		end
	end

	return
end

--[[
	Snapshots a file as the middleware `use` names, under the instance name its rule gave it: project files go to
		SnapshotProject and model files to PluginModelService, neither reading a meta file, `ignore` makes nothing,
		and every other kind reads its adjacent meta (R1.12).
]]
function PluginSnapshotService.SnapshotFile(
	self: PluginSnapshotService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	context: Types.SnapshotContext,
	use: string,
	name: string
): Types.BuildResult<Types.Snapshot?>
	if use == "project" then
		return self:SnapshotProject(fileSystem, path, context, name)
	elseif use == "jsonModel" then
		return PluginModelService:SnapshotJsonModel(fileSystem, path, name)
	elseif use == "rbxm" or use == "rbxmx" then
		return PluginModelService:SnapshotBinaryModel(fileSystem, path, name)
	elseif use == "ignore" then
		return { ok = true }
	end

	local read = fileSystem:ReadFile(path)
	local decoded = if read.ok then decodeFileContents(read.value, use, context.emitLegacyScripts) else read

	if not decoded.ok then
		return buildError(path, decoded.error.message)
	end

	local snapshot = {
		name = name,
		className = decoded.value.className,
		properties = decoded.value.properties,
		children = {},
		path = path,
	}
	local applied = PluginMetaService:ApplyAdjacentMeta(fileSystem, path, name, snapshot)

	if not applied.ok then
		return applied
	end

	return { ok = true, value = snapshot }
end

--[[
	Snapshots a directory (R1.4, R4): the first of `default.project.json`, `default.project.jsonc` and the init
		files that exists makes it a project or an init instance; otherwise it is a Folder of its entries with its
		directory meta applied. Any loaded model is destroyed when the meta files refuse.
]]
function PluginSnapshotService.SnapshotDirectory(
	self: PluginSnapshotService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	context: Types.SnapshotContext,
	name: string
): Types.BuildResult<Types.Snapshot?>
	for _, init in DIRECTORY_INITS do
		local initPath = joinPath(path, init.name)
		local exists = fileSystem:IsFile(initPath) or fileSystem:IsDirectory(initPath)

		if exists and init.use == "project" then
			return self:SnapshotProject(fileSystem, initPath, context, name)
		end

		if exists then
			return self:SnapshotInitDirectory(fileSystem, path, initPath, context, init.use, name)
		end
	end

	local folder = self:SnapshotFolder(fileSystem, path, context, name)

	if not folder.ok then
		return folder
	end

	local applied = PluginMetaService:ApplyDirectoryMeta(fileSystem, path, folder.value)

	if not applied.ok then
		PluginModelService:DestroyModels(folder.value.children)

		return applied
	end

	return folder
end

--[[
	Snapshots a directory whose instance comes from an init script or `init.csv` as Rojo's `snapshot_lua_init`
		does: its entries first, as a Folder without meta, then the init file under the directory's name with its
		adjacent meta (`<dir>/<dirName>.meta.json`, inside the directory), whose `id` is then dropped, and last the
		directory meta, whose `className` the init instance refuses. Any loaded model is destroyed on a refusal.
]]
function PluginSnapshotService.SnapshotInitDirectory(
	self: PluginSnapshotService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	initPath: string,
	context: Types.SnapshotContext,
	use: string,
	name: string
): Types.BuildResult<Types.Snapshot?>
	local folder = self:SnapshotFolder(fileSystem, path, context, name)

	if not folder.ok then
		return folder
	end

	local init = self:SnapshotFile(fileSystem, initPath, context, use, name)

	if not init.ok then
		PluginModelService:DestroyModels(folder.value.children)

		return init
	end

	local snapshot = init.value

	snapshot.children = folder.value.children
	snapshot.id = nil

	local applied = PluginMetaService:ApplyDirectoryMeta(fileSystem, path, snapshot)

	if not applied.ok then
		PluginModelService:DestroyModels(snapshot.children)

		return applied
	end

	return init
end

--[[
	Snapshots a directory as a Folder of its entries without meta, as Rojo's `snapshot_dir_no_meta` does (R4.1):
		entries in byte order, each dispatched by SnapshotPath unless an ignore rule leaves it out, entries that
		make nothing dropped, and DataModels, which Studio's loader drops. When an entry refuses, every model the
		earlier entries loaded is destroyed.
]]
function PluginSnapshotService.SnapshotFolder(
	self: PluginSnapshotService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	context: Types.SnapshotContext,
	name: string
): Types.BuildResult<Types.Snapshot>
	local children = {}

	for _, entry in fileSystem:ListDirectory(path) do
		local entryPath = joinPath(path, entry)
		local child = if isPathIgnored(context.ignoreRules, entryPath)
			then { ok = true }
			else self:SnapshotPath(fileSystem, entryPath, context, entry)

		if not child.ok then
			PluginModelService:DestroyModels(children)

			return child
		end

		if child.value and PluginModelService:KeepsChild(child.value) then
			table.insert(children, child.value)
		end
	end

	return {
		ok = true,
		value = { name = name, className = "Folder", properties = {}, children = children, path = path },
	}
end

--[[
	Snapshots a project file through PluginProjectService (R1.13), `name` being the instance name the file's rule
		or folder gave it, which the project's own `name` overrides. Its `$path` targets come back here through
		SnapshotPath, handed over so the two services never require each other.
]]
function PluginSnapshotService.SnapshotProject(
	self: PluginSnapshotService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	context: Types.SnapshotContext,
	name: string
): Types.BuildResult<Types.Snapshot?>
	return PluginProjectService:SnapshotProject(fileSystem, path, context, name, function(...)
		return self:SnapshotPath(...)
	end)
end

export type PluginSnapshotService = typeof(PluginSnapshotService)

return PluginSnapshotService
