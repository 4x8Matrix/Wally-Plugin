local SerializationService = game:GetService("SerializationService")

local Console = require(script.Parent.Parent.Packages.Console)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginPropertyService = require(script.Parent.PluginPropertyService)
local VirtualFileSystem = require(script.Parent.Parent.PluginClasses.VirtualFileSystem)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)
local decodeJsonModel = require(script.Parent.Parent.PluginUtilities.decodeJsonModel)

local BINARY_HEADER = "<roblox!\137\255\r\n\26\n"
local ONE_INSTANCE = "Rojo currently only supports model files with one top-level instance"
local DROPPED = '%s: the DataModel "%s" is left out, as Studio\'s loader drops a DataModel below other instances'
	.. " with everything under it"

local PluginModelService = {}

PluginModelService.Reporter = Console.new(`🧩 {script.Name}`)

--[[
	Snapshots a `.model.json` or `.model.jsonc` file as Rojo 7.7.1 does (R1.10). The model is named `name`, as
		the caller named the file's instance, so a top-level `name` is ignored with Rojo's warning; the top-level
		`id` becomes the snapshot's Ref id. A blank file gives no snapshot. No adjacent meta file is read.
]]
function PluginModelService.SnapshotJsonModel(
	self: PluginModelService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	name: string
): Types.BuildResult<Types.Snapshot?>
	local read = fileSystem:ReadFile(path)
	local decoded = if read.ok then decodeJsonModel(read.value) else read

	if not decoded.ok then
		return buildError(path, decoded.error.message)
	end

	local model = decoded.value

	if not model then
		return { ok = true }
	end

	if model.name then
		self.Reporter:Warn(
			`Model at path {path} had a top-level Name field. This field has been ignored since Rojo 6.0. `
				.. `Consider removing this field and renaming the file to {model.name}.model.json.`
		)
	end

	local snapshot = self:SnapshotObject(model, path, name)

	if snapshot.ok then
		snapshot.value.id = model.id
	end

	return snapshot
end

--[[
	Turns one model object into a snapshot as Rojo's `into_snapshot` does: its children first, in written order,
		each named by its `name` or else its class and with its `id` dropped; then its properties, resolved
		against its class in key order; then its `attributes`, which replace any `Attributes` property unless
		empty. Every class is kept as Rojo writes it, unchecked; whether a plugin can create it is decided once for
		the whole package, after DataModels are left out (PluginSnapshotService.SnapshotPackage).
]]
function PluginModelService.SnapshotObject(
	self: PluginModelService,
	model: Types.JsonModel,
	path: string,
	name: string
): Types.BuildResult<Types.Snapshot>
	local className = model.className
	local properties = {}
	local children = {}

	for _, child in model.children do
		local snapshot = self:SnapshotObject(child, path, child.name or child.className)

		if not snapshot.ok then
			return snapshot
		end

		if self:KeepsChild(snapshot.value) then
			table.insert(children, snapshot.value)
		end
	end

	local resolved = PluginPropertyService:ResolveProperties(className, model.properties, model.attributes)

	if not resolved.ok then
		return buildError(path, resolved.error.message)
	end

	for _, property in resolved.value do
		properties[property.name] = property.value
	end

	return {
		ok = true,
		value = { name = name, className = className, properties = properties, children = children, path = path },
	}
end

--[[
	Snapshots a `.rbxm` or `.rbxmx` file as Rojo 7.7.1 does (R1.11): its one top-level instance, loaded detached,
		is renamed `name` and held as the snapshot's `model`, its class, properties, attributes, tags, descendants
		and the Refs between them kept as loaded. A file holding no top-level instance or several is refused, and
		whatever it held is destroyed. No adjacent meta file is read.
]]
function PluginModelService.SnapshotBinaryModel(
	self: PluginModelService,
	fileSystem: VirtualFileSystem.VirtualFileSystem,
	path: string,
	name: string
): Types.BuildResult<Types.Snapshot>
	local read = fileSystem:ReadFile(path)
	local loaded = if read.ok then self:LoadInstances(path, read.value) else read

	if not loaded.ok then
		return loaded
	end

	local instances = loaded.value
	local model = instances[1]

	if #instances ~= 1 then
		for _, instance in instances do
			instance:Destroy()
		end

		return buildError(path, ONE_INSTANCE)
	end

	model.Name = name

	return {
		ok = true,
		value = { name = name, className = model.ClassName, properties = {}, children = {}, model = model, path = path },
	}
end

-- seam: a model file a sync rule names without its extension loads either format; upgrade trigger: a package doing it
-- seam: what Studio's loader and Rojo's decoders disagree on follows Studio; upgrade trigger: a conformance mismatch
--[[
	Loads a model file's top-level instances through SerializationService. Rojo decodes `.rbxm` as binary and
		`.rbxmx` as XML, where SerializationService takes either, so a file in the other format is refused here,
		as is anything SerializationService cannot load, in Rojo's words.
]]
function PluginModelService.LoadInstances(
	_: PluginModelService,
	path: string,
	contents: string
): Types.BuildResult<{ Instance }>
	local isXml = string.sub(path, -6) == ".rbxmx"
	local isBinary = string.sub(path, -5) == ".rbxm"
	local holdsBinary = string.sub(contents, 1, #BINARY_HEADER) == BINARY_HEADER

	if isBinary and not holdsBinary then
		return buildError(path, "Malformed rbxm file: Invalid file header")
	end

	if isXml and holdsBinary then
		return buildError(path, "Malformed rbxmx file: it holds a binary model")
	end

	local loaded, instances =
		pcall(SerializationService.DeserializeInstancesAsync, SerializationService, buffer.fromstring(contents))

	if not loaded then
		local format = if isXml then "rbxmx" else "rbxm"

		return buildError(path, `Malformed {format} file: {instances}`)
	end

	return { ok = true, value = instances }
end

--[[
	Whether a snapshot built as a child stays among its parent's children. A DataModel does not: Studio's loader
		drops a DataModel below other instances, with everything under it, when it loads Rojo's build (measured on
		project nodes, project files, `$path` targets, model files and directory meta), so it is left out with a
		warning naming the file it came from, and any model it holds is destroyed.
]]
function PluginModelService.KeepsChild(self: PluginModelService, snapshot: Types.Snapshot): boolean
	if snapshot.className ~= "DataModel" then
		return true
	end

	self.Reporter:Warn(string.format(DROPPED, snapshot.path, snapshot.name))
	self:DestroyModels({ snapshot })

	return false
end

--[[
	Destroys the model every snapshot in the list and below it loaded, when a refusal throws the snapshots away.
]]
function PluginModelService.DestroyModels(self: PluginModelService, snapshots: { Types.Snapshot })
	for _, snapshot in snapshots do
		if snapshot.model then
			snapshot.model:Destroy()
		end

		self:DestroyModels(snapshot.children)
	end
end

export type PluginModelService = typeof(PluginModelService)

return PluginModelService
