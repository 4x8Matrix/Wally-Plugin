local Console = require(script.Parent.Parent.Packages.Console)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginPropertyService = require(script.Parent.PluginPropertyService)
local PluginReflectionService = require(script.Parent.PluginReflectionService)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)

local ID_ATTRIBUTE = "Rojo_Id"
local TARGET_ATTRIBUTE = "^Rojo_Target_(.*)$"
local ROJO_VARIANTS = { boolean = "Bool", number = "Float64", string = "String" }
local UNSETTABLE = { Name = true, Parent = true }

local PluginRefService = {}

PluginRefService.Reporter = Console.new(`🔗 {script.Name}`)

--[[
	Warns why a Ref is left unset and returns the success that carries nothing.
]]
function PluginRefService.Skip(self: PluginRefService, message: string): Types.BuildResult<nil>
	self.Reporter:Warn(message)

	return { ok = true }
end

--[[
	Links Refs as Rojo 7.7.1 does once the whole tree exists (R3.7): every instance under `root`, loaded models'
		included, holds the id its snapshot gave it (`ids`) unless a string `Rojo_Id` attribute replaces it, then
		each `Rojo_Target_<Prop>` attribute sets `<Prop>` to the one instance holding its id, so forward and
		cross-file targets work. The attributes stay. `paths` names the file each snapshot came from, for a refusal.
]]
function PluginRefService.LinkRefs(
	self: PluginRefService,
	root: Instance,
	ids: { [Instance]: string },
	paths: { [Instance]: string }
): Types.BuildResult<nil>
	local instances = root:GetDescendants()
	local holders = {}

	table.insert(instances, 1, root)

	for _, instance in instances do
		local id = self:ReadId(instance, ids[instance])
		local holding = if id then holders[id] or {} else nil

		if holding then
			table.insert(holding, instance)
			holders[id] = holding
		end
	end

	for _, instance in instances do
		for name, value in instance:GetAttributes() do
			local propertyName = string.match(name, TARGET_ATTRIBUTE)
			local linked = if propertyName then self:LinkTarget(instance, propertyName, value, holders) else nil

			if linked and not linked.ok then
				return buildError(self:FindPath(instance, paths), linked.error.message)
			end
		end
	end

	return { ok = true }
end

--[[
	The Rojo variant an attribute value has, as Rojo's warnings name it.
]]
function PluginRefService.VariantOf(_: PluginRefService, value: any): string
	return ROJO_VARIANTS[typeof(value)] or typeof(value)
end

--[[
	The id an instance holds: its `Rojo_Id` attribute when that is a string, else the one its snapshot gave it. Any
		other `Rojo_Id` is passed over with Rojo's warning.
]]
function PluginRefService.ReadId(self: PluginRefService, instance: Instance, snapshotId: string?): string?
	local attribute = instance:GetAttribute(ID_ATTRIBUTE)
	local variant = self:VariantOf(attribute)

	if variant == "String" then
		return attribute
	end

	if variant ~= "nil" then
		self.Reporter:Warn(
			`Attribute {ID_ATTRIBUTE} is of type {variant} when it was expected to be a String `
				.. `({instance:GetFullName()})`
		)
	end

	return snapshotId
end

--[[
	Sets one `Rojo_Target_<Prop>` as Rojo's patch applier and writer do. A target that is not a string, an id no
		instance or several instances hold, Name and Parent, a property Studio does not know and a Ref Studio will
		not let a plugin set are left unset with a warning; a property whose written type is not a Ref is refused
		in the words of Rojo's writer, which refuses the Ref it was given.
]]
function PluginRefService.LinkTarget(
	self: PluginRefService,
	instance: Instance,
	propertyName: string,
	value: any,
	holders: { [string]: { Instance } }
): Types.BuildResult<nil>
	local variant = self:VariantOf(value)
	local holding = if variant == "String" then holders[value] else nil
	local property = PluginReflectionService:FindProperty(instance.ClassName, propertyName)
	local target = `{instance.ClassName}.{propertyName}`
	local where = instance:GetFullName()

	if variant ~= "String" then
		return self:Skip(
			`Attribute Rojo_Target_{propertyName} is of type {variant} when it was expected to be a String ({where})`
		)
	end

	if not holding then
		return self:Skip(`No instance has the id '{value}', so {target} is left unset ({where})`)
	end

	if #holding > 1 then
		return self:Skip(`The id '{value}' is shared by {#holding} instances, so {target} is left unset ({where})`)
	end

	if UNSETTABLE[propertyName] then
		return self:Skip(`{target} is not set through a Ref, so it is left as it is ({where})`)
	end

	if not property then
		return self:Skip(
			`{target} was left out: Studio does not know the property, so it drops the Ref Rojo writes for it ({where})`
		)
	end

	local checked = PluginPropertyService:CheckWriterVariant(target, property, "Ref")

	if not checked.ok then
		return buildError("", `{checked.error.message} on instance {where}`)
	end

	return self:SetTarget(instance, propertyName, holding[1])
end

--[[
	Sets a Ref property, or warns when Studio will not let a plugin set it.
]]
function PluginRefService.SetTarget(
	self: PluginRefService,
	instance: Instance,
	propertyName: string,
	targetInstance: Instance
): Types.BuildResult<nil>
	local set, reason = pcall(function()
		(instance :: any)[propertyName] = targetInstance
	end)

	if not set then
		return self:Skip(`{instance.ClassName}.{propertyName} could not be set: {reason} ({instance:GetFullName()})`)
	end

	return { ok = true }
end

--[[
	The file the instance came from: its own snapshot's, or for an instance a model file loaded, the nearest
		snapshot's above it.
]]
function PluginRefService.FindPath(_: PluginRefService, instance: Instance, paths: { [Instance]: string }): string
	local holder: Instance? = instance

	while holder and not paths[holder] do
		holder = holder.Parent
	end

	return if holder then paths[holder] else ""
end

export type PluginRefService = typeof(PluginRefService)

return PluginRefService
