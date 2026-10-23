local Types = require(script.Parent.Types)

local kindOfDataValue = require(script.Parent.kindOfDataValue)
local toFloat32 = require(script.Parent.toFloat32)

local ESCAPES = { ["\0"] = "\\0", ["\t"] = "\\t", ["\n"] = "\\n", ["\r"] = "\\r", ['"'] = '\\"', ["\\"] = "\\\\" }
local VECTOR_FIELDS = { Color3 = { "R", "G", "B" }, Vector2 = { "X", "Y" }, Vector3 = { "X", "Y", "Z" } }
local MATERIAL_ORDER = {
	"Grass",
	"Slate",
	"Concrete",
	"Brick",
	"Sand",
	"WoodPlanks",
	"Rock",
	"Glacier",
	"Snow",
	"Sandstone",
	"Mud",
	"Basalt",
	"Ground",
	"CrackedLava",
	"Asphalt",
	"Cobblestone",
	"Ice",
	"LeafyGrass",
	"Salt",
	"Limestone",
	"Pavement",
}

--[[
	Prints a number as Rust's `{:?}` prints an f64, or an f32 when `single`: the shortest digits that read back, as
		a decimal with at least one fractional digit, or in exponent form below 1e-4 and from 1e16.
]]
local function describeNumber(number: number, single: boolean?): string
	local magnitude = math.abs(number)
	local sign = if number < 0 or 1 / number < 0 then "-" else ""
	local mantissa, exponent = "0", 0

	for precision = 0, 16 do
		local text = string.format(`%.{precision}e`, magnitude)
		local readBack = tonumber(text)

		if (if single then toFloat32(readBack) else readBack) == magnitude then
			local digits, power = string.match(text, "^([%d.]+)e([-+]%d+)$")

			mantissa, exponent = string.gsub(digits, "%.", ""), tonumber(power)

			break
		end
	end

	if magnitude == 0 then
		return `{sign}0.0`
	end

	if magnitude < 1e-4 or magnitude >= 1e16 then
		local fraction = string.sub(mantissa, 2)

		return `{sign}{string.sub(mantissa, 1, 1)}{if fraction == "" then "" else "." .. fraction}e{exponent}`
	end

	if exponent < 0 then
		return `{sign}0.{string.rep("0", -exponent - 1)}{mantissa}`
	end

	local whole = string.sub(mantissa .. string.rep("0", exponent + 1), 1, exponent + 1)
	local fraction = string.sub(mantissa, exponent + 2)

	return `{sign}{whole}.{if fraction == "" then "0" else fraction}`
end

local function describeString(text: string): string
	local escaped = string.gsub(text, '[%c"\\]', function(character)
		return ESCAPES[character] or string.format("\\u{%x}", string.byte(character))
	end)

	return `"{escaped}"`
end

--[[
	Prints an explicit value as Rust's `{:?}` prints the Variant, exactly for scalars, vectors and colours and by
		name with its value elided otherwise.
]]
local function describeVariant(parsed: Types.ParsedValue): string
	local variant, value = parsed.variant, parsed.value
	local fields = {}

	if variant == "Bool" then
		return `Bool({value})`
	elseif variant == "String" then
		return `String({describeString(value)})`
	elseif variant == "Float32" or variant == "Float64" then
		return `{variant}({describeNumber(value, variant == "Float32")})`
	elseif variant == "Int32" or variant == "Int64" then
		return `{variant}({string.format("%d", value)})`
	elseif VECTOR_FIELDS[variant] then
		for _, field in VECTOR_FIELDS[variant] do
			table.insert(fields, `{string.lower(field)}: {describeNumber(value[field], true)}`)
		end

		return `{variant}({variant} \{ {table.concat(fields, ", ")} })`
	end

	return `{variant}(..)`
end

--[[
	The `cachedFaceId` a Font was written with, which the parsed Font no longer holds: from an object's field or
		an array's fourth item.
]]
local function findCachedFaceId(source: Types.DataValue): string?
	local kind = kindOfDataValue(source)

	if kind == "array" then
		return if kindOfDataValue(source.items[4]) == "string" then source.items[4] else nil
	end

	for _, entry in if kind == "map" then source.entries else {} do
		if entry.key == "cachedFaceId" and kindOfDataValue(entry.value) == "string" then
			return entry.value
		end
	end

	return
end

--[[
	Prints an implicit value as Rust's `{:?}` prints Rojo's AmbiguousValue, the text Rojo refuses an attribute
		with when no single type fits it: StringArray, Array2 to Array12, Attributes, Font and MaterialColors.
]]
return function(parsed: Types.ParsedValue): string
	local variant, value = parsed.variant, parsed.value
	local items = {}

	if variant == "StringArray" then
		for _, item in value do
			table.insert(items, describeString(item))
		end

		return `StringArray([{table.concat(items, ", ")}])`
	elseif variant == "Attributes" then
		for _, attribute in value do
			table.insert(items, `{describeString(attribute.name)}: {describeVariant(attribute.parsed)}`)
		end

		return `Attributes(Attributes \{ data: \{{table.concat(items, ", ")}} })`
	elseif variant == "Font" then
		local cachedFaceId = findCachedFaceId(parsed.source)
		local cached = if cachedFaceId then `Some({describeString(cachedFaceId)})` else "None"

		return `Font(Font \{ family: {describeString(value.Family)}, weight: {value.Weight.Name}, `
			.. `style: {value.Style.Name}, cached_face_id: {cached} })`
	elseif variant == "MaterialColors" then
		for _, material in MATERIAL_ORDER do
			local channels = value[material]

			if channels then
				table.insert(items, `{material}: Color3uint8 \{ r: {channels[1]}, g: {channels[2]}, b: {channels[3]} }`)
			end
		end

		return `MaterialColors(MaterialColors \{ inner: \{{table.concat(items, ", ")}} })`
	end

	for _, number in value do
		table.insert(items, describeNumber(number))
	end

	return `{variant}([{table.concat(items, ", ")}])`
end
