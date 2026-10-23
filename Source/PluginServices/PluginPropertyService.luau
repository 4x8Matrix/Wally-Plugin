local Console = require(script.Parent.Parent.Packages.Console)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginReflectionService = require(script.Parent.PluginReflectionService)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)
local castToInteger = require(script.Parent.Parent.PluginUtilities.castToInteger)
local describeParsedValue = require(script.Parent.Parent.PluginUtilities.describeParsedValue)
local findEnum = require(script.Parent.Parent.PluginUtilities.findEnum)
local listEnumItems = require(script.Parent.Parent.PluginUtilities.listEnumItems)
local parseDataValue = require(script.Parent.Parent.PluginUtilities.parseDataValue)
local roundColorToBytes = require(script.Parent.Parent.PluginUtilities.roundColorToBytes)
local toFloat32 = require(script.Parent.Parent.PluginUtilities.toFloat32)

local UNWRITABLE_VARIANTS =
	{ Attributes = true, EnumItem = true, Region3 = true, Region3int16 = true, Vector2int16 = true }
local ATTRIBUTE_VARIANTS = {
	BinaryString = true,
	Bool = true,
	BrickColor = true,
	CFrame = true,
	Color3 = true,
	ColorSequence = true,
	EnumItem = true,
	Float32 = true,
	Float64 = true,
	Font = true,
	Int32 = true,
	NumberRange = true,
	NumberSequence = true,
	Rect = true,
	String = true,
	UDim = true,
	UDim2 = true,
	Vector2 = true,
	Vector3 = true,
}
local UNAMBIGUOUS = { Bool = "Bool", Number = "Float64", String = "String" }
local STRING_WRITER = {
	label = "String, ContentId, Tags, Attributes, MaterialColors, or BinaryString",
	accepts = {
		Attributes = true,
		BinaryString = true,
		ContentId = true,
		MaterialColors = true,
		String = true,
		Tags = true,
	},
}
local SHARED_STRING_WRITER =
	{ label = "SharedString or NetAssetRef", accepts = { NetAssetRef = true, SharedString = true } }
local WRITERS = {
	BinaryString = STRING_WRITER,
	BrickColor = { label = "BrickColor", accepts = { BrickColor = true, Int32 = true } },
	Color3uint8 = { label = "Color3uint8 or Color3", accepts = { Color3 = true, Color3uint8 = true } },
	ContentId = STRING_WRITER,
	Enum = { label = "Enum or EnumItem", accepts = { Enum = true, EnumItem = true } },
	Float64 = { label = "Float64", accepts = { Float32 = true, Float64 = true } },
	Int64 = { label = "Int64", accepts = { Int32 = true, Int64 = true } },
	NetAssetRef = SHARED_STRING_WRITER,
	SharedString = SHARED_STRING_WRITER,
	String = STRING_WRITER,
}
local DESCRIPTIONS = {
	Array12 = "an array of twelve numbers",
	Array2 = "an array of two numbers",
	Array3 = "an array of three numbers",
	Array4 = "an array of four numbers",
	Attributes = "an object containing attributes",
	Bool = "a bool",
	Font = "an object describing a Font",
	MaterialColors = "an object describing MaterialColors",
	Number = "a number",
	String = "a string",
	StringArray = "an array of strings",
}
local IMPLICIT_FORMS = {
	["Bool Bool"] = true,
	["CFrame Array12"] = true,
	["Color3 Array3"] = true,
	["Content String"] = true,
	["ContentId String"] = true,
	["Float32 Number"] = true,
	["Float64 Number"] = true,
	["Font Font"] = true,
	["Int32 Number"] = true,
	["Int64 Number"] = true,
	["MaterialColors MaterialColors"] = true,
	["String String"] = true,
	["Tags StringArray"] = true,
	["Vector2 Array2"] = true,
	["Vector3 Array3"] = true,
}

local PluginPropertyService = {}

PluginPropertyService.Reporter = Console.new(`🧱 {script.Name}`)
PluginPropertyService.Nil = table.freeze({})

--[[
	Warns why a value is left out and returns the success that carries nothing to apply.
]]
function PluginPropertyService.Skip(self: PluginPropertyService, message: string): Types.BuildResult<any>
	self.Reporter:Warn(message)

	return { ok = true }
end

--[[
	Builds a NumberRange, or leaves it out with a warning: Studio holds a reversed range from Rojo's build, but a
		plugin cannot construct one.
]]
function PluginPropertyService.ToRange(
	self: PluginPropertyService,
	target: string,
	bounds: { number }
): Types.BuildResult<any>
	local built, range = pcall(NumberRange.new, bounds[1], bounds[2])

	if not built then
		return self:Skip(
			`{target} was left out: Studio holds the NumberRange {bounds[1]} to {bounds[2]} from Rojo's build, `
				.. "but a plugin cannot construct it"
		)
	end

	return { ok = true, value = range }
end

--[[
	Turns one explicit attribute value into what Studio loads for it from Rojo's build. A type the attribute writer
		cannot write fails in rbx_types' words; Int32 attributes, EnumItems of an unknown enum or item and
		reversed ranges are left out with a warning, since Studio drops them on load or a plugin cannot make them.
]]
function PluginPropertyService.ToAttribute(
	self: PluginPropertyService,
	name: string,
	parsed: Types.ParsedValue
): Types.BuildResult<any>
	local variant, value = parsed.variant, parsed.value
	local target = `Attribute {name}`

	if not ATTRIBUTE_VARIANTS[variant] then
		return buildError("", `{variant} values are not supported in attributes`)
	end

	if variant == "Int32" then
		return self:Skip(`{target} was left out: it is an Int32, which Studio drops when it loads Rojo's build`)
	elseif variant == "EnumItem" then
		local enum = findEnum(value.enumType)
		local item = enum and enum:FromValue(value.value)

		return if item
			then { ok = true, value = item }
			else self:Skip(
				`{target} was left out: {value.enumType} has no item {value.value}, `
					.. "so Studio drops it when it loads Rojo's build"
			)
	elseif variant == "BrickColor" then
		return { ok = true, value = BrickColor.new(value) }
	elseif variant == "NumberRange" then
		return self:ToRange(target, value)
	end

	return { ok = true, value = value }
end

--[[
	Turns a list of named explicit attribute values into the name-to-value map Apply sets, leaving out those
		ToAttribute leaves out.
]]
function PluginPropertyService.ToAttributes(
	self: PluginPropertyService,
	attributes: { Types.ParsedAttribute }
): Types.BuildResult<{ [string]: any }>
	local converted = {}

	for _, attribute in attributes do
		local result = self:ToAttribute(attribute.name, attribute.parsed)

		if not result.ok then
			return result
		end

		converted[attribute.name] = result.value
	end

	return { ok = true, value = converted }
end

--[[
	Resolves `$attributes`, a meta file's or a model's `attributes`: each value explicit, or an implicit bool,
		number or string, as Bool, Float64 and String. Anything else fails in Rojo's words, and values become what
		Studio loads for them, as ToAttribute says.
]]
function PluginPropertyService.ResolveAttributes(
	self: PluginPropertyService,
	map: Types.DataMap
): Types.BuildResult<{ [string]: any }>
	local attributes = {}

	for _, entry in map.entries do
		local result = parseDataValue(entry.value)
		local parsed = if result.ok then result.value else nil

		if not parsed then
			return result
		end

		if not parsed.explicit and not UNAMBIGUOUS[parsed.variant] then
			return buildError("", `Cannot unambiguously resolve the value {describeParsedValue(parsed)}`)
		end

		table.insert(attributes, {
			name = entry.key,
			parsed = if parsed.explicit
				then parsed
				else {
					explicit = true,
					variant = UNAMBIGUOUS[parsed.variant],
					value = parsed.value,
					holdsNil = false,
					source = entry.value,
				},
		})
	end

	return self:ToAttributes(attributes)
end

-- seam: implicit values resolve by Studio's reflection, not Rojo's database 741; upgrade trigger: a mismatch on one
--[[
	Resolves an implicit value against the property's type, as Rojo's AmbiguousValue does: an enum item by exact
		name, a number for the numeric types (cast as Rust casts), a string for strings and content, arrays of 2, 3
		or 12 numbers for vectors, colours and CFrames, an array of strings for Tags, and the attribute, Font and
		MaterialColors objects for their types. Anything else fails in Rojo's words.
]]
function PluginPropertyService.ResolveImplicit(
	self: PluginPropertyService,
	className: string,
	propertyName: string,
	property: PluginReflectionService.PropertyRecord?,
	parsed: Types.ParsedValue
): Types.BuildResult<any>
	local target = `{className}.{propertyName}`
	local form, value = parsed.variant, parsed.value

	if not property then
		return buildError("", `Unknown property {target}`)
	end

	local rojoType = property.rojoType
	local key = `{rojoType} {form}`

	if rojoType == "Enum" then
		local enum = Enum[property.enumType]
		local item = if form == "String" then enum:FromName(value) else nil
		local got = if form == "String" then value else DESCRIPTIONS[form]

		if item then
			return { ok = true, value = item }
		end

		local members = listEnumItems(enum)

		return buildError(
			"",
			`Invalid value for property {target}. Got {got} but expected a member of the {property.enumType} enum `
				.. `such as {members}`
		)
	end

	if key == "Attributes Attributes" then
		return self:ToAttributes(value)
	end

	if key == "Ref String" then
		return buildError(
			"",
			`Cannot resolve Ref properties as a String.Use an attribute named \`Rojo_Target_{propertyName}`
		)
	end

	if not IMPLICIT_FORMS[key] then
		return buildError(
			"",
			`Wrong type of value for property {target}. Expected {rojoType}, got {DESCRIPTIONS[form]}`
		)
	end

	local resolved = if key == "Float32 Number"
		then toFloat32(value)
		elseif key == "Int32 Number" then castToInteger(value, -2 ^ 31, 2 ^ 31 - 1)
		elseif key == "Int64 Number" then castToInteger(value, -2 ^ 63, 2 ^ 63 - 1)
		elseif key == "Content String" then Content.fromUri(value)
		elseif key == "Vector2 Array2" then Vector2.new(table.unpack(value))
		elseif key == "Vector3 Array3" then Vector3.new(table.unpack(value))
		elseif key == "Color3 Array3" then Color3.new(table.unpack(value))
		elseif key == "CFrame Array12" then CFrame.new(table.unpack(value))
		else value

	return {
		ok = true,
		value = if rojoType == "Color3" and property.writtenType == "Color3uint8"
			then roundColorToBytes(resolved)
			else resolved,
	}
end

--[[
	Turns an explicit value that passed the writer's type check into what Studio holds for Rojo's build of it.
		An enum value with no item is left out, as Studio loads it as the default; SecurityCapabilities are left
		out, as Studio reads Rojo's bits as other capabilities (bits 0, 1 and 7 load as none, measured), and a
		model holding some cannot be loaded by a plugin at all.
]]
function PluginPropertyService.ToPropertyValue(
	self: PluginPropertyService,
	target: string,
	property: PluginReflectionService.PropertyRecord,
	parsed: Types.ParsedValue
): Types.BuildResult<any>
	local variant, value = parsed.variant, parsed.value
	local stringType = WRITERS[property.writtenType] == STRING_WRITER

	if parsed.holdsNil then
		return { ok = true, value = self.Nil }
	elseif variant == "Enum" or variant == "EnumItem" then
		local number = if variant == "Enum" then value else value.value
		local item = Enum[property.enumType]:FromValue(number)

		return if item
			then { ok = true, value = item }
			else self:Skip(
				`{target} was left out: {property.enumType} has no item {number}, `
					.. "so Studio loads Rojo's build with the default"
			)
	elseif variant == "SecurityCapabilities" then
		return self:Skip(`{target} was left out: Studio does not read SecurityCapabilities bits as Rojo writes them`)
	elseif variant == "BrickColor" or (variant == "Int32" and property.writtenType == "BrickColor") then
		return { ok = true, value = BrickColor.new(value) }
	elseif variant == "Color3" and property.writtenType == "Color3uint8" then
		return { ok = true, value = roundColorToBytes(value) }
	elseif variant == "Tags" and stringType then
		return { ok = true, value = table.concat(value, "\0") }
	elseif (variant == "Attributes" or variant == "MaterialColors") and stringType then
		return self:Skip(
			`{target} was left out: Rojo writes {variant} into it as encoded bytes, which is not reproduced`
		)
	elseif variant == "Attributes" then
		return self:ToAttributes(value)
	elseif variant == "NumberRange" then
		return self:ToRange(target, value)
	end

	return { ok = true, value = value }
end

-- seam: Content on a migrating ContentId property (ImageLabel.Image) is refused; upgrade trigger: a package doing it
-- seam: String on a migrating ContentId property is accepted where Rojo refuses; upgrade trigger: a package doing it
-- seam: Font on TextLabel.Font is refused where Rojo's migration takes it; upgrade trigger: a package doing it
-- seam: Tags and Attributes refuse a String, which Rojo writes into them raw; upgrade trigger: a package doing it
--[[
	Resolves an explicit value. One for a property Studio does not know is left out with a warning, since Rojo
		writes it under its own name and Studio drops it on load, unless Rojo's writer has no type for the variant
		and refuses it. One for a known property must be a variant the writer accepts for the property's written
		type, else it is refused with the writer's wording.
]]
function PluginPropertyService.ResolveExplicit(
	self: PluginPropertyService,
	className: string,
	propertyName: string,
	property: PluginReflectionService.PropertyRecord?,
	parsed: Types.ParsedValue
): Types.BuildResult<any>
	local target = `{className}.{propertyName}`
	local variant = parsed.variant

	if not property and UNWRITABLE_VARIANTS[variant] then
		return buildError("", `Unsupported property type: {target} is of type {variant}`)
	end

	if not property then
		return self:Skip(
			`{target} was left out: Studio does not know the property, so it drops what Rojo writes for it`
		)
	end

	local checked = self:CheckWriterVariant(target, property, variant)

	if not checked.ok then
		return checked
	end

	return self:ToPropertyValue(target, property, parsed)
end

--[[
	Refuses a variant Rojo's writer does not accept for the property's written type, in the writer's words, as
		Rojo's build fails on it. `target` names the property as `<Class>.<Property>`.
]]
function PluginPropertyService.CheckWriterVariant(
	_: PluginPropertyService,
	target: string,
	property: PluginReflectionService.PropertyRecord,
	variant: string
): Types.BuildResult<nil>
	local writer = WRITERS[property.writtenType]
		or { label = property.writtenType, accepts = { [property.writtenType] = true } }

	if not writer.accepts[variant] then
		return buildError(
			"",
			`Property type mismatch: Expected {target} to be of type {writer.label}, but it was of type {variant}`
		)
	end

	return { ok = true }
end

-- seam: properties Rojo's database marks unserialized are still applied; upgrade trigger: a conformance mismatch on one
-- seam: a property a plugin cannot set (Part.size) is left out; upgrade trigger: a conformance mismatch on one
--[[
	Resolves one property value as Rojo 7.7.1 does (R3) into the Roblox value Studio holds for Rojo's build: an
		explicit `{"<Variant>": ...}` value by its variant, checked against the type Rojo's writer writes the
		property as, and any other value by the property's type in ReflectionService. A value Studio would not
		hold, or that a plugin cannot set, comes back as a success holding nothing, with a warning; so do `Name`
		and `Parent`, which no build sets (Rojo drops them from `$properties` and its writer ignores them from meta
		and model files, measured).
]]
function PluginPropertyService.ResolveProperty(
	self: PluginPropertyService,
	className: string,
	propertyName: string,
	value: Types.DataValue
): Types.BuildResult<any>
	local result = parseDataValue(value)
	local parsed = if result.ok then result.value else nil
	local property = PluginReflectionService:FindProperty(className, propertyName)
	local target = `{className}.{propertyName}`

	if not parsed then
		return result
	end

	local resolved = if parsed.explicit
		then self:ResolveExplicit(className, propertyName, property, parsed)
		else self:ResolveImplicit(className, propertyName, property, parsed)

	if not resolved.ok or not property then
		return resolved
	end

	if propertyName == "Name" or propertyName == "Parent" then
		return self:Skip(`Property '{propertyName}' cannot be set manually, ignoring ({target})`)
	end

	if not property.writable then
		return self:Skip(`{target} was left out: a plugin cannot set it`)
	end

	return resolved
end

--[[
	Resolves the properties and attributes a meta file, a model object or a project node gives an instance, as Rojo
		7.7.1 applies them: each property through ResolveProperty against the class in key order, then a non-empty
		attribute map as `Attributes`, into the entries to set in that order. An entry ResolveProperty leaves out
		holds no value, for the caller to clear or keep. A refusal is in Rojo's words, which name the `origin`
		(`project`) a refusal came from when one is given.
]]
function PluginPropertyService.ResolveProperties(
	self: PluginPropertyService,
	className: string,
	properties: Types.DataMap,
	attributes: Types.DataMap,
	origin: string?
): Types.BuildResult<{ ResolvedProperty }>
	local resolved = {}

	for _, entry in properties.entries do
		local property = self:ResolveProperty(className, entry.key, entry.value)

		if not property.ok then
			local message = property.error.message

			return buildError("", if origin then `Unresolvable property in {origin}: {message}` else message)
		end

		table.insert(resolved, { name = entry.key, value = property.value })
	end

	local attributeMap = if #attributes.entries > 0 then self:ResolveAttributes(attributes) else nil

	if attributeMap and not attributeMap.ok then
		local message = attributeMap.error.message

		return buildError("", if origin then `Unresolvable attribute in {origin}: {message}` else message)
	end

	if attributeMap then
		table.insert(resolved, { name = "Attributes", value = attributeMap.value })
	end

	return { ok = true, value = resolved }
end

export type ResolvedProperty = { name: string, value: any }
export type PluginPropertyService = typeof(PluginPropertyService)

return PluginPropertyService
