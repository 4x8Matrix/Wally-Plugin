local Console = require(script.Parent.Parent.Packages.Console)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginModelService = require(script.Parent.PluginModelService)
local PluginPropertyService = require(script.Parent.PluginPropertyService)
local PluginReflectionService = require(script.Parent.PluginReflectionService)
local VirtualFileSystem = require(script.Parent.Parent.PluginClasses.VirtualFileSystem)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)
local buildProjectContext = require(script.Parent.Parent.PluginUtilities.buildProjectContext)
local chooseNodeClass = require(script.Parent.Parent.PluginUtilities.chooseNodeClass)
local decodeProjectFile = require(script.Parent.Parent.PluginUtilities.decodeProjectFile)
local fileNameOfPath = require(script.Parent.Parent.PluginUtilities.fileNameOfPath)
local joinPath = require(script.Parent.Parent.PluginUtilities.joinPath)
local parentOfPath = require(script.Parent.Parent.PluginUtilities.parentOfPath)

local INFERRED_CHILDREN = {
	StarterPlayer = { StarterPlayerScripts = true, StarterCharacterScripts = true },
	Workspace = { Terrain = true },
}
local CYCLE = "the project reaches its own file through $path, which overflows Rojo 7.7.1's stack"
local NO_DIRECTORY_NAME = "Could not extract directory name (Rojo 7.7.1 crashes on a $path ending in `..`)"
local NOT_A_DIRECTORY = "Not a directory (os error 20)"
local RESERVED = "Keys starting with '$' are reserved by Rojo to ensure forward compatibility. "
	.. "This project uses the key '%s', which should be renamed."

local PluginProjectService = {}

PluginProjectService.Reporter = Console.new(`📐 {script.Name}`)
PluginProjectService.Entered = setmetatable({}, { __mode = "k" }) :: EnteredProjects

--[[
	Snapshots a project file as Rojo 7.7.1's `snapshot_project` does (R1.13, R2.6): its tree, named by the
		project's `name` or else `name`, the fallback its rule or folder gave it, built in the project's own context.
		`snapshotPath` is PluginSnapshotService's SnapshotPath, which `$path` targets go through. A project reached
		again inside its own tree is refused, naming it as first reached, where Rojo recurses until its stack
		overflows.
]]
function PluginProjectService.SnapshotProject(
	self: PluginProjectService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	context: Types.SnapshotContext,
	name: string,
	snapshotPath: SnapshotPath
): Types.BuildResult<Types.Snapshot?>
	local key = fileSystem:Resolve(path) or path
	local entered = self.Entered[fileSystem] or {}

	if entered[key] then
		return buildError(entered[key], CYCLE)
	end

	self.Entered[fileSystem] = entered
	entered[key] = path

	local snapshot = self:SnapshotProjectFile(fileSystem, path, context, name, snapshotPath)

	entered[key] = nil

	return snapshot
end

--[[
	Reads and decodes a project file, refusing one that does not read as Rojo refuses it, warns for its `$` keys as
		Rojo does when it loads the file, and snapshots its tree as the project's root node, which has no parent.
]]
function PluginProjectService.SnapshotProjectFile(
	self: PluginProjectService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	context: Types.SnapshotContext,
	name: string,
	snapshotPath: SnapshotPath
): Types.BuildResult<Types.Snapshot?>
	local read = fileSystem:ReadFile(path)
	local decoded = if read.ok then decodeProjectFile(read.value) else read

	if not decoded.ok then
		return buildError(path, `File was not a valid Rojo project: {decoded.error.message}`)
	end

	local folder = parentOfPath(path)
	local project = {
		path = path,
		folder = folder,
		context = buildProjectContext(decoded.value, folder, context),
		snapshotPath = snapshotPath,
	}

	self:WarnReservedNames(decoded.value.tree)

	return self:SnapshotNode(fileSystem, project, decoded.value.name or name, decoded.value.tree)
end

--[[
	Warns for every child key starting with `$` anywhere in the tree, built or not, in Rojo's words.
]]
function PluginProjectService.WarnReservedNames(self: PluginProjectService, node: Types.ProjectNode)
	for _, child in node.children do
		if string.sub(child.name, 1, 1) == "$" then
			self.Reporter:Warn(string.format(RESERVED, child.name))
		end

		self:WarnReservedNames(child.node)
	end
end

--[[
	Snapshots a project node as Rojo 7.7.1's `snapshot_project_node` does (R2.3, R2.5): its `$path` target first,
		then its class, then its children after the target's, in key order, then its `$properties` over the
		target's properties and a non-empty `$attributes` replacing every attribute, and its `$id` over the
		target's. The node takes its key as its name. Every class is kept as Rojo writes it, so a DataModel is built
		whole, raising Rojo's refusals inside it, for its parent to leave out as Studio's loader does; whether a
		plugin can create a class is decided once for the package. Every model the node holds is destroyed on a
		refusal.
]]
function PluginProjectService.SnapshotNode(
	self: PluginProjectService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	project: Project,
	name: string,
	node: Types.ProjectNode,
	parentClass: string?
): Types.BuildResult<Types.Snapshot?>
	local target = if node.path then self:SnapshotTarget(fileSystem, project, node.path.path) else { ok = true }

	if not target.ok then
		return target
	end

	local found = target.value
	local inferred = self:InferClassName(name, parentClass)
	local chosen = chooseNodeClass(name, node.className, found and found.className, inferred, node.path)

	if not chosen.ok then
		PluginModelService:DestroyModels({ found })

		return buildError(project.path, chosen.error.message)
	end

	if not chosen.value then
		return { ok = true }
	end

	local snapshot = {
		name = name,
		className = chosen.value,
		properties = if found then found.properties else {},
		children = if found then found.children else {},
		id = node.id or (found and found.id),
		model = found and found.model,
		path = project.path,
	}
	local built = self:SnapshotChildren(fileSystem, project, node, snapshot)
	local applied = if built.ok then self:ApplyNode(project, node, snapshot) else built

	if not applied.ok then
		PluginModelService:DestroyModels({ snapshot })

		return applied
	end

	return { ok = true, value = snapshot }
end

--[[
	Snapshots a node's children in key order onto the end of the snapshot's, each with the node's class as its
		parent's, dropping those that make nothing and DataModels, which Studio's loader drops.
]]
function PluginProjectService.SnapshotChildren(
	self: PluginProjectService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	project: Project,
	node: Types.ProjectNode,
	snapshot: Types.Snapshot
): Types.BuildResult<nil>
	for _, child in node.children do
		local built = self:SnapshotNode(fileSystem, project, child.name, child.node, snapshot.className)

		if not built.ok then
			return built
		end

		if built.value and PluginModelService:KeepsChild(built.value) then
			table.insert(snapshot.children, built.value)
		end
	end

	return { ok = true }
end

--[[
	Resolves a node's `$properties` against its class in key order over what the snapshot holds, a value
		PluginPropertyService leaves out keeping what was there, then replaces `Attributes` with a non-empty
		`$attributes`.
]]
function PluginProjectService.ApplyNode(
	_: PluginProjectService,
	project: Project,
	node: Types.ProjectNode,
	snapshot: Types.Snapshot
): Types.BuildResult<nil>
	local resolved =
		PluginPropertyService:ResolveProperties(snapshot.className, node.properties, node.attributes, "project")
	local kept = {}

	if not resolved.ok then
		return buildError(project.path, resolved.error.message)
	end

	for _, property in resolved.value do
		kept[property.name] = property.value
	end

	for propertyName, value in kept do
		snapshot.properties[propertyName] = value
	end

	return { ok = true }
end

-- seam: an absolute $path, which Rojo reads from the host, finds nothing; upgrade trigger: a package using one
-- seam: a $path ending in `..` leaving the zip finds nothing; Rojo crashes; upgrade trigger: a package doing it
-- seam: a $path naming the zip root is named "", not after the package folder; upgrade trigger: a package doing it
--[[
	Snapshots what a `$path` names (R2.4): the path joined to the project's folder without normalising `..`,
		then dispatched by SnapshotPath in the project's context, ignore rules never applying to the target itself.
		A path running through a file is refused as Rojo's metadata query refuses it, and a directory reached by a
		path ending in `..`, which has no file name, as Rojo crashes on it. One trailing `/` goes, as Rust's join
		drops it before a child's name.
]]
function PluginProjectService.SnapshotTarget(
	_: PluginProjectService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	project: Project,
	path: string
): Types.BuildResult<Types.Snapshot?>
	local full = joinPath(project.folder, path)
	local name = fileNameOfPath(full)
	local trimmed = if string.sub(full, -1) == "/" then string.sub(full, 1, -2) else full

	if string.sub(path, 1, 1) == "/" then
		return { ok = true }
	end

	if fileSystem:RunsThroughFile(full) then
		return buildError(project.path, `failed to query metadata of file \`{full}\`: {NOT_A_DIRECTORY}`)
	end

	if not name and fileSystem:IsDirectory(full) then
		return buildError(project.path, NO_DIRECTORY_NAME)
	end

	return project.snapshotPath(fileSystem, trimmed, project.context, name)
end

-- seam: a service is what GetService fetches, not database 741's tag; upgrade trigger: a mismatch under a DataModel
--[[
	The class Rojo 7.7.1's `infer_class_name` gives a node from its key and its parent's final class: a service under
		a DataModel, StarterPlayerScripts and StarterCharacterScripts under StarterPlayer, Terrain under Workspace,
		and nothing under anything else or at a project's root.
]]
function PluginProjectService.InferClassName(_: PluginProjectService, name: string, parentClass: string?): string?
	local inferable = if parentClass then INFERRED_CHILDREN[parentClass] else nil

	if parentClass == "DataModel" then
		return if PluginReflectionService:IsService(name) then name else nil
	end

	return if inferable and inferable[name] then name else nil
end

type SnapshotPath = (
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	context: Types.SnapshotContext,
	name: string?
) -> Types.BuildResult<Types.Snapshot?>
type Project = { path: string, folder: string, context: Types.SnapshotContext, snapshotPath: SnapshotPath }
type EnteredProjects = { [VirtualFileSystem.VirtualFileSystem]: { [string]: string } }

export type PluginProjectService = typeof(PluginProjectService)

return PluginProjectService
