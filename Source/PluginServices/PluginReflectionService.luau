local ReflectionService = game:GetService("ReflectionService")

local isPluginPermitted = require(script.Parent.Parent.PluginUtilities.isPluginPermitted)

local ENGINE_TYPES = {
	CoordinateFrame = "CFrame",
	OptionalCoordinateFrame = "OptionalCFrame",
	ProtectedString = "String",
	Rect2D = "Rect",
	RefType = "Ref",
	Region3Int16 = "Region3int16",
	Vector3Int16 = "Vector3int16",
	bool = "Bool",
	double = "Float64",
	float = "Float32",
	int = "Int32",
	int64 = "Int64",
	string = "String",
}
local ROJO_TYPES = {
	["Instance.Attributes"] = "Attributes",
	["Instance.Tags"] = "Tags",
	["Terrain.MaterialColors"] = "MaterialColors",
}
local WRITTEN_TYPES = { ["BasePart.Color"] = "Color3uint8" }
local SET_THROUGH_METHODS = { ["LocalizationTable.Contents"] = "SetContents" }

local PluginReflectionService = {}

PluginReflectionService.ReflectionFilter = {
	Security = ReflectionService:GetClass("Folder").Permits.New
		:Add(table.unpack(Enum.SecurityCapability:GetEnumItems())),
}
PluginReflectionService.Classes = {} :: { [string]: ClassRecord | false }

--[[
	Reads a class from ReflectionService once: whether a plugin may create it, whether it is a service, and for
		each property the type Rojo resolves implicit values against, the type Rojo's writer checks explicit values
		against, its enum, whether a plugin may set it and the method that sets it where assigning it fails (named
		in PluginApplyService). An unknown class is remembered as `false`. The filter
		holds every capability, since the default one hides Tags, Attributes and UniqueId; it is built onto
		Folder's empty creation permit because selene's standard library predates `SecurityCapabilities.new`.
]]
function PluginReflectionService.GetClass(self: PluginReflectionService, className: string): ClassRecord?
	local cached = self.Classes[className]

	if cached == false then
		return
	end

	if cached then
		return cached
	end

	local class = ReflectionService:GetClass(className, self.ReflectionFilter)

	if not class then
		self.Classes[className] = false

		return
	end

	local properties = {}

	for _, property in ReflectionService:GetPropertiesOfClass(className, self.ReflectionFilter) do
		local owned = `{property.Owner}.{property.Name}`
		local rojoType = ROJO_TYPES[owned] or ENGINE_TYPES[property.Type.EngineType] or property.Type.EngineType
		local setter = SET_THROUGH_METHODS[owned]

		properties[property.Name] = {
			rojoType = rojoType,
			writtenType = WRITTEN_TYPES[owned] or rojoType,
			enumType = property.Type.EnumType,
			writable = if rojoType == "Tags"
					or rojoType == "Attributes"
					or setter
				then true
				else isPluginPermitted(property.Permits.Write),
			setter = setter,
		}
	end

	local record = {
		creatable = isPluginPermitted(class.Permits.New),
		service = if class.Permits.GetService then true else false,
		properties = properties,
	}

	self.Classes[className] = record

	return record
end

--[[
	Whether a plugin can create the class: ReflectionService lists it with a `Permits.New` a plugin holds.
]]
function PluginReflectionService.ClassExists(self: PluginReflectionService, className: string): boolean
	local class = self:GetClass(className)

	return if class then class.creatable else false
end

--[[
	Whether the class is a service, which ReflectionService gives a `Permits.GetService`.
]]
function PluginReflectionService.IsService(self: PluginReflectionService, className: string): boolean
	local class = self:GetClass(className)

	return if class then class.service else false
end

--[[
	The property as GetClass recorded it, found on the class or any superclass, or nil when either is unknown.
]]
function PluginReflectionService.FindProperty(
	self: PluginReflectionService,
	className: string,
	propertyName: string
): PropertyRecord?
	local class = self:GetClass(className)

	return if class then class.properties[propertyName] else nil
end

export type ClassRecord = { creatable: boolean, service: boolean, properties: { [string]: PropertyRecord } }
export type PropertyRecord = {
	rojoType: string,
	writtenType: string,
	enumType: string?,
	writable: boolean,
	setter: string?,
}
export type PluginReflectionService = typeof(PluginReflectionService)

return PluginReflectionService
