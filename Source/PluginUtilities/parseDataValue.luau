local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local decodeBase64 = require(script.Parent.decodeBase64)
local kindOfDataValue = require(script.Parent.kindOfDataValue)
local toFloat32 = require(script.Parent.toFloat32)

local UNTAGGED = "data did not match any variant of untagged enum UnresolvedValue"
local HOLDS_NIL = table.freeze({})
local VARIANTS = {
	Attributes = true,
	Axes = true,
	BinaryString = true,
	Bool = true,
	BrickColor = true,
	CFrame = true,
	Color3 = true,
	Color3uint8 = true,
	ColorSequence = true,
	Content = true,
	ContentId = true,
	Enum = true,
	EnumItem = true,
	Faces = true,
	Float32 = true,
	Float64 = true,
	Font = true,
	Int32 = true,
	Int64 = true,
	MaterialColors = true,
	NetAssetRef = true,
	NumberRange = true,
	NumberSequence = true,
	OptionalCFrame = true,
	PhysicalProperties = true,
	Ray = true,
	Rect = true,
	Ref = true,
	Region3 = true,
	Region3int16 = true,
	SecurityCapabilities = true,
	SharedString = true,
	String = true,
	Tags = true,
	UDim = true,
	UDim2 = true,
	UniqueId = true,
	Vector2 = true,
	Vector2int16 = true,
	Vector3 = true,
	Vector3int16 = true,
}
local NUMBER_ARRAYS = { [2] = "Array2", [3] = "Array3", [4] = "Array4", [12] = "Array12" }
local FLOAT_TUPLES = {
	Color3 = { count = 3, new = Color3.new },
	Vector2 = { count = 2, new = Vector2.new },
	Vector3 = { count = 3, new = Vector3.new },
}
local INTEGER_TUPLES = {
	Color3uint8 = { count = 3, minimum = 0, maximum = 255, new = Color3.fromRGB },
	Vector2int16 = { count = 2, minimum = -32768, maximum = 32767, new = Vector2int16.new },
	Vector3int16 = { count = 3, minimum = -32768, maximum = 32767, new = Vector3int16.new },
}
local CORNERS = { Rect = "Vector2", Region3 = "Vector3", Region3int16 = "Vector3int16" }
local AXES = { X = Enum.Axis.X, Y = Enum.Axis.Y, Z = Enum.Axis.Z }
local FACES = {
	Back = Enum.NormalId.Back,
	Bottom = Enum.NormalId.Bottom,
	Front = Enum.NormalId.Front,
	Left = Enum.NormalId.Left,
	Right = Enum.NormalId.Right,
	Top = Enum.NormalId.Top,
}
local FONT_WEIGHTS = {
	Bold = Enum.FontWeight.Bold,
	ExtraBold = Enum.FontWeight.ExtraBold,
	ExtraLight = Enum.FontWeight.ExtraLight,
	Heavy = Enum.FontWeight.Heavy,
	Light = Enum.FontWeight.Light,
	Medium = Enum.FontWeight.Medium,
	Regular = Enum.FontWeight.Regular,
	SemiBold = Enum.FontWeight.SemiBold,
	Thin = Enum.FontWeight.Thin,
}
local FONT_STYLES = { Italic = Enum.FontStyle.Italic, Normal = Enum.FontStyle.Normal }
local FONT_FIELDS = { "family", "weight", "style", "cachedFaceId" }
local PHYSICAL_FIELDS =
	{ "density", "friction", "elasticity", "frictionWeight", "elasticityWeight", "acousticAbsorption" }
local COLOR_KEYPOINT_FIELDS = { "time", "color" }
local NUMBER_KEYPOINT_FIELDS = { "time", "value", "envelope" }
local TERRAIN_MATERIALS = {
	Asphalt = true,
	Basalt = true,
	Brick = true,
	Cobblestone = true,
	Concrete = true,
	CrackedLava = true,
	Glacier = true,
	Grass = true,
	Ground = true,
	Ice = true,
	LeafyGrass = true,
	Limestone = true,
	Mud = true,
	Pavement = true,
	Rock = true,
	Salt = true,
	Sand = true,
	Sandstone = true,
	Slate = true,
	Snow = true,
	WoodPlanks = true,
}

local readVariant: (variant: string, value: Types.DataValue) -> any

-- seam: an integer written as 1.0, -0 or 1e3 is accepted where Rojo refuses; upgrade trigger: a package relying on it
local function readInteger(value: Types.DataValue?, minimum: number, maximum: number): number?
	if kindOfDataValue(value) ~= "number" or value % 1 ~= 0 or value < minimum or value > maximum then
		return
	end

	return value
end

local function readList(value: Types.DataValue?, read: (item: Types.DataValue) -> any): { any }?
	if kindOfDataValue(value) ~= "array" then
		return
	end

	local items = {}

	for _, item in value.items do
		local readItem = read(item)

		if not readItem then
			return
		end

		table.insert(items, readItem)
	end

	return items
end

local function readNumbers(value: Types.DataValue?, count: number?): { number }?
	local numbers = readList(value, function(item)
		return if kindOfDataValue(item) == "number" then item else nil
	end)

	if not numbers or (count and #numbers ~= count) then
		return
	end

	return numbers
end

--[[
	Reads a struct as serde derives one: an object holding every named field, unknown fields ignored and the
		`optional` one allowed to be missing, or an array with exactly one item per field, in order.
]]
local function readFields(value: Types.DataValue?, names: { string }, optional: string?): { [string]: Types.DataValue }?
	local kind = kindOfDataValue(value)
	local fields = {}

	if kind == "array" and #value.items == #names then
		for index, name in names do
			fields[name] = value.items[index]
		end

		return fields
	end

	if kind ~= "map" then
		return
	end

	for _, entry in value.entries do
		if table.find(names, entry.key) then
			fields[entry.key] = entry.value
		end
	end

	for _, name in names do
		if not fields[name] and name ~= optional then
			return
		end
	end

	return fields
end

local function readNumberFields(value: Types.DataValue?, names: { string }): { number }?
	local fields = readFields(value, names)
	local numbers = {}

	if not fields then
		return
	end

	for _, name in names do
		if kindOfDataValue(fields[name]) ~= "number" then
			return
		end

		table.insert(numbers, fields[name])
	end

	return numbers
end

--[[
	Whether a string is a referent as Rust's `u128::from_str_radix(_, 16)` reads one: an optional `+`, then hex
		digits worth less than 2^128.
]]
local function isReferent(value: Types.DataValue?): boolean
	local digits = if kindOfDataValue(value) == "string" then string.match(value, "^%+?(%x+)$") else nil

	return if digits then #string.match(digits, "^0*(.*)$") <= 32 else false
end

--[[
	Whether a string is a UniqueId as rbx_types parses one: 32 bytes, the first 16 a signed 64-bit hex number and
		the other two groups of eight unsigned 32-bit ones.
]]
local function isUniqueId(value: Types.DataValue): boolean
	if kindOfDataValue(value) ~= "string" or #value ~= 32 then
		return false
	end

	local random = string.sub(value, 1, 16)
	local signed = string.match(random, "^[+-]%x+$") or string.match(random, "^[0-7]%x+$")
	local time = string.match(string.sub(value, 17, 24), "^%+?%x+$")
	local index = string.match(string.sub(value, 25, 32), "^%+?%x+$")

	return if signed and time and index then true else false
end

local function readCFrame(value: Types.DataValue?): CFrame?
	local fields = readFields(value, { "position", "orientation" })
	local position = fields and readNumbers(fields.position, 3)
	local rows = fields and readList(fields.orientation, function(row)
		return readNumbers(row, 3)
	end)

	if not position or not rows or #rows ~= 3 then
		return
	end

	return CFrame.new(
		position[1],
		position[2],
		position[3],
		rows[1][1],
		rows[1][2],
		rows[1][3],
		rows[2][1],
		rows[2][2],
		rows[2][3],
		rows[3][1],
		rows[3][2],
		rows[3][3]
	)
end

--[[
	Reads a Font: a string `family`, a `weight` and `style` by name, and an optional `cachedFaceId` that is a
		string or null and is otherwise ignored, since Studio finds the face itself.
]]
local function readFont(value: Types.DataValue): Font?
	local fields = readFields(value, FONT_FIELDS, "cachedFaceId")
	local weight = fields and FONT_WEIGHTS[fields.weight]
	local style = fields and FONT_STYLES[fields.style]
	local cachedKind = fields and kindOfDataValue(fields.cachedFaceId)

	if not weight or not style or kindOfDataValue(fields.family) ~= "string" then
		return
	end

	if cachedKind ~= "nil" and cachedKind ~= "string" and cachedKind ~= "null" then
		return
	end

	return Font.new(fields.family, weight, style)
end

--[[
	Reads MaterialColors: an object of terrain material names to byte colours, kept as each name's channels.
]]
local function readMaterialColors(value: Types.DataValue): { [string]: { number } }?
	if kindOfDataValue(value) ~= "map" then
		return
	end

	local colors = {}

	for _, entry in value.entries do
		local channels = TERRAIN_MATERIALS[entry.key]
			and readList(entry.value, function(channel)
				return readInteger(channel, 0, 255)
			end)

		if not channels or #channels ~= 3 then
			return
		end

		colors[entry.key] = channels
	end

	return colors
end

--[[
	Reads a value as an explicit `{"<Variant>": <value>}`: an object with one key naming a variant whose value
		reads as that variant. Bool is read here, since `false` is a value readVariant cannot return.
]]
local function parseExplicit(value: Types.DataValue): Types.ParsedValue?
	local entry = if kindOfDataValue(value) == "map" and #value.entries == 1 then value.entries[1] else nil
	local bool = if entry and entry.key == "Bool" then kindOfDataValue(entry.value) == "boolean" else false
	local read = if entry and not bool and VARIANTS[entry.key] then readVariant(entry.key, entry.value) else nil
	local holdsNil = read == HOLDS_NIL

	if not bool and not read then
		return
	end

	return {
		explicit = true,
		variant = entry.key,
		value = if bool then entry.value elseif holdsNil then nil else read,
		holdsNil = holdsNil,
		source = entry.value,
	}
end

--[[
	Reads an object of attribute names to explicit values, in key order, or nothing when one value is not explicit.
]]
local function readAttributeMap(value: Types.DataValue): { Types.ParsedAttribute }?
	if kindOfDataValue(value) ~= "map" then
		return
	end

	local attributes = {}

	for _, entry in value.entries do
		local parsed = parseExplicit(entry.value)

		if not parsed then
			return
		end

		table.insert(attributes, { name = entry.key, parsed = parsed })
	end

	return attributes
end

--[[
	Reads Content as rbx_types does: `"None"`, `{"Uri": string}`, or `{"Object": referent}`, which Studio loads
		as None since the referent points at nothing in the build.
]]
local function readContent(value: Types.DataValue): Content?
	local entry = if kindOfDataValue(value) == "map" and #value.entries == 1 then value.entries[1] else nil

	if value == "None" or (entry and entry.key == "Object" and isReferent(entry.value)) then
		return Content.none
	end

	return if entry
			and entry.key == "Uri"
			and kindOfDataValue(entry.value) == "string"
		then Content.fromUri(entry.value)
		else nil
end

--[[
	Builds a ColorSequence or NumberSequence from `{"keypoints": [...]}`. Studio loads a sequence it would not
		construct (fewer than two keypoints, out of order, not spanning 0 to 1) as white or zero, measured on
		Rojo's builds, so that is what such a sequence becomes here.
]]
local function readSequence(variant: string, value: Types.DataValue): any
	local fields = readFields(value, { "keypoints" })
	local keypoints = fields
		and readList(fields.keypoints, function(keypoint)
			local parts = readFields(
				keypoint,
				if variant == "ColorSequence" then COLOR_KEYPOINT_FIELDS else NUMBER_KEYPOINT_FIELDS
			)
			local color = parts and variant == "ColorSequence" and readVariant("Color3", parts.color)
			local numbers = parts and variant == "NumberSequence" and readNumberFields(keypoint, NUMBER_KEYPOINT_FIELDS)

			if color and kindOfDataValue(parts.time) == "number" then
				return { parts.time, color }
			end

			return numbers
		end)

	if not keypoints then
		return
	end

	local built, sequence = pcall(function()
		local list = {}

		for _, keypoint in keypoints do
			table.insert(
				list,
				if variant == "ColorSequence"
					then ColorSequenceKeypoint.new(keypoint[1], keypoint[2])
					else NumberSequenceKeypoint.new(keypoint[1], keypoint[2], keypoint[3])
			)
		end

		return if variant == "ColorSequence" then ColorSequence.new(list) else NumberSequence.new(list)
	end)

	if built then
		return sequence
	end

	return if variant == "ColorSequence" then ColorSequence.new(Color3.new(1, 1, 1)) else NumberSequence.new(0)
end

--[[
	Reads the value of an explicit `{"<Variant>": <value>}` as rbx_types 3.1.0 deserializes that variant, or
		nothing when the shape is wrong. Most come back as the Roblox value; Enum and EnumItem come back as their
		numbers, NumberRange as its bounds and Region3 as its corners, since what they become depends on where
		they go, and a value Studio holds as nil (a Ref, PhysicalProperties "Default", a null OptionalCFrame) comes
		back as HOLDS_NIL.
]]
function readVariant(variant: string, value: Types.DataValue): any
	local kind = kindOfDataValue(value)
	local floats = FLOAT_TUPLES[variant]
	local integers = INTEGER_TUPLES[variant]

	if variant == "String" or variant == "ContentId" then
		return if kind == "string" then value else nil
	elseif variant == "BinaryString" or variant == "SharedString" or variant == "NetAssetRef" then
		local decoded = if kind == "string" then decodeBase64(value) else nil

		return if decoded and decoded.ok then decoded.value else nil
	elseif variant == "Float32" then
		return if kind == "number" then toFloat32(value) else nil
	elseif variant == "Float64" then
		return if kind == "number" then value else nil
	elseif variant == "Int32" then
		return readInteger(value, -2 ^ 31, 2 ^ 31 - 1)
	elseif variant == "Int64" then
		return readInteger(value, -2 ^ 63, 2 ^ 63 - 1)
	elseif variant == "Enum" then
		return readInteger(value, 0, 2 ^ 32 - 1)
	elseif variant == "SecurityCapabilities" then
		return readInteger(value, 0, 2 ^ 64 - 1)
	elseif variant == "BrickColor" then
		local number = readInteger(value, 0, 2 ^ 16 - 1)

		return if number and BrickColor.new(number).Number == number then number else nil
	elseif floats then
		local numbers = readNumbers(value, floats.count)

		return if numbers then floats.new(table.unpack(numbers)) else nil
	elseif integers then
		local numbers = readList(value, function(item)
			return readInteger(item, integers.minimum, integers.maximum)
		end)

		return if numbers and #numbers == integers.count then integers.new(table.unpack(numbers)) else nil
	elseif variant == "NumberRange" then
		return readNumbers(value, 2)
	elseif variant == "UDim" then
		local scale = if kind == "array" and #value.items == 2 then value.items[1] else nil
		local offset = if scale then readInteger(value.items[2], -2 ^ 31, 2 ^ 31 - 1) else nil

		return if offset and kindOfDataValue(scale) == "number" then UDim.new(scale, offset) else nil
	elseif variant == "UDim2" then
		local parts = readList(value, function(item)
			return readVariant("UDim", item)
		end)

		return if parts and #parts == 2 then UDim2.new(parts[1], parts[2]) else nil
	elseif CORNERS[variant] then
		local corners = readList(value, function(item)
			return readVariant(CORNERS[variant], item)
		end)

		if not corners or #corners ~= 2 then
			return
		end

		return if variant == "Rect" then Rect.new(corners[1], corners[2]) else corners
	elseif variant == "CFrame" then
		return readCFrame(value)
	elseif variant == "OptionalCFrame" then
		return if kind == "null" then HOLDS_NIL else readCFrame(value)
	elseif variant == "Ray" then
		local fields = readFields(value, { "origin", "direction" })
		local origin = fields and readVariant("Vector3", fields.origin)
		local direction = fields and readVariant("Vector3", fields.direction)

		return if origin and direction then Ray.new(origin, direction) else nil
	elseif variant == "Axes" or variant == "Faces" then
		local names = if variant == "Axes" then AXES else FACES
		local items = readList(value, function(item)
			return names[item]
		end)

		if not items then
			return
		end

		return if variant == "Axes" then Axes.new(table.unpack(items)) else Faces.new(table.unpack(items))
	elseif variant == "ColorSequence" or variant == "NumberSequence" then
		return readSequence(variant, value)
	elseif variant == "PhysicalProperties" then
		local numbers = if kind == "map" then readNumberFields(value, PHYSICAL_FIELDS) else nil

		if value == "Default" then
			return HOLDS_NIL
		end

		return if numbers then PhysicalProperties.new(table.unpack(numbers)) else nil
	elseif variant == "Ref" then
		return if isReferent(value) then HOLDS_NIL else nil
	elseif variant == "Content" then
		return readContent(value)
	elseif variant == "Tags" then
		return readList(value, function(item)
			return if kindOfDataValue(item) == "string" then item else nil
		end)
	elseif variant == "Attributes" then
		return readAttributeMap(value)
	elseif variant == "Font" then
		return readFont(value)
	elseif variant == "UniqueId" then
		return if isUniqueId(value) then value else nil
	elseif variant == "MaterialColors" then
		return readMaterialColors(value)
	elseif variant == "EnumItem" then
		local fields = readFields(value, { "type", "value" })
		local number = fields and readInteger(fields.value, 0, 2 ^ 32 - 1)

		return if number and kindOfDataValue(fields.type) == "string"
			then { enumType = fields.type, value = number }
			else nil
	end

	return
end

--[[
	Reads a decoded property or attribute value as Rojo 7.7.1's untagged UnresolvedValue does: explicit first,
		then each implicit form in serde's order, bool, string, array of strings, number, array of 2, 3, 4 or 12
		numbers, attribute object, Font, MaterialColors. Anything else fails in serde's words. An explicit value
		Studio holds as nil comes back with no value and `holdsNil` set. The error names no path; the caller adds
		the file.
]]
return function(value: Types.DataValue): Types.BuildResult<Types.ParsedValue>
	local explicit = parseExplicit(value)
	local kind = kindOfDataValue(value)
	local strings = readVariant("Tags", value)
	local numbers = readNumbers(value)
	local attributes = readAttributeMap(value)
	local font = readFont(value)
	local colors = readMaterialColors(value)
	local form = if kind == "boolean"
		then "Bool"
		elseif kind == "string" then "String"
		elseif strings then "StringArray"
		elseif kind == "number" then "Number"
		elseif numbers and NUMBER_ARRAYS[#numbers] then NUMBER_ARRAYS[#numbers]
		elseif attributes then "Attributes"
		elseif font then "Font"
		elseif colors then "MaterialColors"
		else nil

	if explicit then
		return { ok = true, value = explicit }
	end

	if not form then
		return buildError("", UNTAGGED)
	end

	local parsed = if form == "StringArray"
		then strings
		elseif string.sub(form, 1, 5) == "Array" then numbers
		elseif form == "Attributes" then attributes
		elseif form == "Font" then font
		elseif form == "MaterialColors" then colors
		else value

	return { ok = true, value = { explicit = false, variant = form, value = parsed, holdsNil = false, source = value } }
end
