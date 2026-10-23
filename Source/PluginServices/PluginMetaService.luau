local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginPropertyService = require(script.Parent.PluginPropertyService)
local VirtualFileSystem = require(script.Parent.Parent.PluginClasses.VirtualFileSystem)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)
local decodeMetaFile = require(script.Parent.Parent.PluginUtilities.decodeMetaFile)
local joinPath = require(script.Parent.Parent.PluginUtilities.joinPath)
local parentOfPath = require(script.Parent.Parent.PluginUtilities.parentOfPath)

local FOLDER_ONLY =
	"className in init.meta.json can only be specified if the affected directory would turn into a Folder instance."

local PluginMetaService = {}

--[[
	Applies the adjacent meta files of the instance a file became (R1.12): `<name>.meta.json`, then
		`<name>.meta.jsonc`, beside the file, where `name` is the instance's name after its rule stripped the file
		name, so `foo.server.lua` reads `foo.meta.json` and an init file reads `<dir>/<dirName>.meta.json`.
]]
function PluginMetaService.ApplyAdjacentMeta(
	self: PluginMetaService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	name: string,
	snapshot: Types.Snapshot
): Types.BuildResult<nil>
	local directory = parentOfPath(path)
	local paths = { joinPath(directory, `{name}.meta.json`), joinPath(directory, `{name}.meta.jsonc`) }

	return self:ApplyMetaFiles(fileSystem, paths, snapshot, false)
end

--[[
	Applies a directory's meta files to the instance it became (R1.12): `init.meta.json`, then `init.meta.jsonc`,
		inside it.
]]
function PluginMetaService.ApplyDirectoryMeta(
	self: PluginMetaService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	directory: string,
	snapshot: Types.Snapshot
): Types.BuildResult<nil>
	local paths = { joinPath(directory, "init.meta.json"), joinPath(directory, "init.meta.jsonc") }

	return self:ApplyMetaFiles(fileSystem, paths, snapshot, true)
end

--[[
	Applies one instance's pair of meta files in order, each that exists. A meta file that is a directory or
		cannot be read fails, as does one that does not decode, in Rojo's words. The second file's `$schema`
		replaces the first's, and both giving one fails, as Rojo's metadata does.
]]
function PluginMetaService.ApplyMetaFiles(
	self: PluginMetaService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	paths: { string },
	snapshot: Types.Snapshot,
	isDirectory: boolean
): Types.BuildResult<nil>
	local kind = if isDirectory then "init.meta.json" else ".meta.json"
	local schema = nil

	for _, path in paths do
		local present = fileSystem:IsFile(path) or fileSystem:IsDirectory(path)
		local read = if present then fileSystem:ReadFile(path) else nil
		local decoded = if read and read.ok then decodeMetaFile(read.value, isDirectory) else nil

		if not read then
			continue
		end

		if not read.ok then
			return read
		end

		if not decoded.ok then
			return buildError(path, `File contained malformed {kind} data: {decoded.error.message}`)
		end

		local applied = self:ApplyMetaFile(path, decoded.value, snapshot)

		if not applied.ok then
			return applied
		end

		if decoded.value.schema and schema then
			return buildError(path, "cannot specify a schema (instance has a schema from somewhere else)")
		end

		schema = decoded.value.schema
	end

	return { ok = true }
end

--[[
	Applies one decoded meta file as Rojo's metadata `apply_all` does: a directory meta's `className` while the
		instance is still a Folder, then each property resolved against the class in key order, then `attributes`
		replacing `Attributes` whole unless empty, then `id`, which replaces the instance's, clears it when absent,
		and fails when both give one. A value PluginPropertyService leaves out clears what the instance had, so the
		property keeps its default, as Studio loads Rojo's build of it (measured: `RunContext` `{"Enum": 99}` over a
		server script loads as Legacy). The class is applied unchecked, as Rojo writes it; whether a plugin can create
		it is decided once for the whole package (PluginSnapshotService.SnapshotPackage).
]]
function PluginMetaService.ApplyMetaFile(
	_: PluginMetaService,
	path: string,
	meta: Types.MetaFile,
	snapshot: Types.Snapshot
): Types.BuildResult<nil>
	if meta.className and snapshot.className ~= "Folder" then
		return buildError(path, FOLDER_ONLY)
	end

	local className = meta.className or snapshot.className
	local resolved = PluginPropertyService:ResolveProperties(className, meta.properties, meta.attributes)

	if not resolved.ok then
		return buildError(path, resolved.error.message)
	end

	if meta.id and snapshot.id then
		return buildError(path, "cannot specify an ID (instance has an ID from somewhere else)")
	end

	snapshot.className = className

	for _, property in resolved.value do
		snapshot.properties[property.name] = property.value
	end

	snapshot.id = meta.id

	return { ok = true }
end

export type PluginMetaService = typeof(PluginMetaService)

return PluginMetaService
