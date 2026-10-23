local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginApplyService = require(script.Parent.PluginApplyService)
local PluginModelService = require(script.Parent.PluginModelService)
local PluginReflectionService = require(script.Parent.PluginReflectionService)
local PluginRefService = require(script.Parent.PluginRefService)
local PluginSnapshotService = require(script.Parent.PluginSnapshotService)
local VirtualFileSystem = require(script.Parent.Parent.PluginClasses.VirtualFileSystem)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)

local UNEXPECTED = "the build stopped on an unexpected error: "
local MOVED_APART = { Attributes = true, Name = true, Parent = true, Tags = true }

local PluginSerialiserService = {}

--[[
	Builds a package zip into instances as Rojo 7.7.1 builds the package's folder in Wally's layout, the root named
		`name`. A zip that cannot be read is refused.
]]
function PluginSerialiserService.SerialiseZipIntoRobloxInstances(
	self: PluginSerialiserService,
	zip: string,
	name: string
): Types.BuildResult<Instance>
	local opened = VirtualFileSystem.fromZip(zip)

	if not opened.ok then
		return opened
	end

	return self:SerialiseFileSystem(opened.value, name)
end

-- seam: models a snapshot loaded before an unexpected error are left to the GC; upgrade trigger: a leak after one
--[[
	Builds a package's files: snapshots them through PluginSnapshotService, then instantiates the snapshot. The
		whole pipeline runs under pcall, so an unexpected error from package data, a stack overflow on pathological
		nesting say, becomes a refusal instead of a crash in the install pipeline.
]]
function PluginSerialiserService.SerialiseFileSystem(
	self: PluginSerialiserService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	name: string
): Types.BuildResult<Instance>
	local ran, result = pcall(function()
		local snapshot = PluginSnapshotService:SnapshotPackage(fileSystem, name)

		return if snapshot.ok then self:Instantiate(snapshot.value) else snapshot
	end)

	return if ran then result else buildError("", `{UNEXPECTED}{result}`)
end

--[[
	Creates a snapshot's instances (spec, Data flow 4): depth first with children in snapshot order, then links Refs
		once the whole tree exists. On a refusal or an unexpected error, every instance built and every model the
		snapshot loaded is destroyed before the result returns, so nothing reaches the place.
]]
function PluginSerialiserService.Instantiate(
	self: PluginSerialiserService,
	snapshot: Types.Snapshot
): Types.BuildResult<Instance>
	local build = { created = {}, ids = {}, paths = {} }
	local ran, result = pcall(function()
		local root = self:Build(snapshot, build)
		local linked = if root.ok then PluginRefService:LinkRefs(root.value, build.ids, build.paths) else root

		return if linked.ok then root else linked
	end)
	local built = if ran then result else buildError("", `{UNEXPECTED}{result}`)

	if not built.ok then
		self:DestroyBuild(snapshot, build)
	end

	return built
end

--[[
	Creates one snapshot's instance under the snapshot's name, applies its properties and records its id and file,
		then builds its children under it in order, after the children a loaded model already holds.
]]
function PluginSerialiserService.Build(
	self: PluginSerialiserService,
	snapshot: Types.Snapshot,
	build: Build
): Types.BuildResult<Instance>
	local created = self:Create(snapshot)
	local instance = if created.ok then created.value else nil

	if not instance then
		return created
	end

	table.insert(build.created, instance)
	build.ids[instance] = snapshot.id
	build.paths[instance] = snapshot.path
	instance.Name = snapshot.name

	local applied = PluginApplyService:Apply(instance, snapshot.properties)

	if not applied.ok then
		return buildError(snapshot.path, applied.error.message)
	end

	for _, child in snapshot.children do
		local builtChild = self:Build(child, build)

		if not builtChild.ok then
			return builtChild
		end

		builtChild.value.Parent = instance
	end

	return created
end

--[[
	The instance a snapshot stands for: its loaded model when the classes agree, else a new instance of its class,
		which takes over a loaded model of another class (a Folder under `$className` or an inferred class, R2.3).
		Whether a plugin can create the class was decided once for the package (PluginSnapshotService.SnapshotPackage).
]]
function PluginSerialiserService.Create(
	self: PluginSerialiserService,
	snapshot: Types.Snapshot
): Types.BuildResult<Instance>
	local model = snapshot.model

	if model and model.ClassName == snapshot.className then
		return { ok = true, value = model }
	end

	local instance = Instance.new(snapshot.className)
	local taken = if model then self:TakeOverModel(model, instance) else { ok = true }

	if not taken.ok then
		instance:Destroy()

		return buildError(snapshot.path, taken.error.message)
	end

	return { ok = true, value = instance }
end

--[[
	Gives a new instance what a loaded model of another class held, as Rojo writes the node's class with the model's
		properties: its children, attributes and tags, and every other property the new class has, a plugin can set
		on it, and the model holds differently. The model is destroyed.
]]
function PluginSerialiserService.TakeOverModel(
	_: PluginSerialiserService,
	model: Instance,
	instance: Instance
): Types.BuildResult<nil>
	local class = PluginReflectionService:GetClass(model.ClassName)
	local properties = { Attributes = model:GetAttributes(), Tags = model:GetTags() }

	for name in class.properties do
		local shared = PluginReflectionService:FindProperty(instance.ClassName, name)
		local held, value = pcall(function()
			return (model :: any)[name]
		end)
		local had, current = pcall(function()
			return (instance :: any)[name]
		end)

		if shared and shared.writable and held and had and value ~= current and not MOVED_APART[name] then
			properties[name] = value
		end
	end

	for _, child in model:GetChildren() do
		child.Parent = instance
	end

	model:Destroy()

	return PluginApplyService:Apply(instance, properties)
end

--[[
	Destroys every instance a failed build created and every model its snapshot loaded.
]]
function PluginSerialiserService.DestroyBuild(_: PluginSerialiserService, snapshot: Types.Snapshot, build: Build)
	for _, instance in build.created do
		instance:Destroy()
	end

	PluginModelService:DestroyModels({ snapshot })
end

type Build = { created: { Instance }, ids: { [Instance]: string }, paths: { [Instance]: string } }

export type PluginSerialiserService = typeof(PluginSerialiserService)

return PluginSerialiserService
