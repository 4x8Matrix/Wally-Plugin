local Types = require(script.Parent.Types)

local BARE_KEY_TYPES = { string = true }
local ESCAPES = { ['"'] = '\\"', ["\r"] = "\\r", ["\n"] = "\\n", ["\t"] = "\\t", ["\\"] = "\\\\" }
local IDENTIFIER_PATTERN = "^[%a_][%w_]*$"
local KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
}

local Encoders = {}

--[[
	Splits `text`, a number as Luau writes it, into its sign, its significant digits without leading or trailing
		zeros, and how many of those digits belong before the decimal point, which is zero or less when the point
		is followed by zeros.
]]
local function splitDigits(text: string): (string, string, number)
	local sign, integer, fraction, exponent = string.match(text, "^(%-?)(%d+)%.?(%d*)[eE]?([%+%-]?%d*)$")
	local digits = `{integer}{fraction}`
	local leading = #string.match(digits, "^0*")
	local significant = string.match(string.sub(digits, leading + 1), "^(.-)0*$")

	return sign, significant, #integer + (tonumber(exponent) or 0) - leading
end

--[[
	Adds one to the last of `digits`, carrying into the digits before it, and says whether the carry ran off the
		front, which moves the decimal point one place right.
]]
local function bumpDigits(digits: string): (string, number)
	local position = #digits

	while string.sub(digits, position, position) == "9" do
		position -= 1
	end

	if position == 0 then
		return `1{string.rep("0", #digits - 1)}`, 1
	end

	local bumped = tonumber(string.sub(digits, position, position)) + 1

	return `{string.sub(digits, 1, position - 1)}{bumped}{string.rep("0", #digits - position)}`, 0
end

local function encodeValue(value: Types.DataValue, level: number): string
	return Encoders[typeof(value)](value, level)
end

local function encodeKey(key: Types.DataValue, level: number): string
	local identifier = if BARE_KEY_TYPES[typeof(key)] then string.match(key, IDENTIFIER_PATTERN) else nil

	if identifier and not KEYWORDS[identifier] then
		return identifier
	end

	return `[{encodeValue(key, level)}]`
end

function Encoders.boolean(value: boolean): string
	return tostring(value)
end

-- seam: via %.99g, a double with 80 zeros after the deciding digit ends one low; upgrade trigger: a number mismatch
--[[
	Writes `value` the way Rust prints an `f64`: the fewest digits that read back as the same double, always in
		plain decimal. Luau's `tostring` gives that digit count, but rounds a value exactly between two digit
		strings to the even digit where Rust rounds away from zero, so the digits themselves are rounded again from
		the exact decimal expansion.
]]
function Encoders.number(value: number): string
	if value ~= value then
		return "0/0"
	end

	if value == math.huge then
		return "math.huge"
	end

	if value == -math.huge then
		return "-math.huge"
	end

	local _, shortest = splitDigits(tostring(value))
	local sign, digits, point = splitDigits(string.format("%.99g", value))

	if #digits > #shortest then
		local kept = string.sub(digits, 1, #shortest)
		local deciding = tonumber(string.sub(digits, #shortest + 1, #shortest + 1))

		if deciding >= 5 then
			local bumped, carried = bumpDigits(kept)

			kept = bumped
			point += carried
		end

		digits = string.match(kept, "^(.-)0*$")
	end

	if digits == "" then
		return `{sign}0`
	end

	if point <= 0 then
		return `{sign}0.{string.rep("0", -point)}{digits}`
	end

	if point >= #digits then
		return `{sign}{digits}{string.rep("0", point - #digits)}`
	end

	return `{sign}{string.sub(digits, 1, point)}.{string.sub(digits, point + 1)}`
end

function Encoders.string(value: string): string
	local escaped = string.gsub(value, '["\r\n\t\\]', ESCAPES)

	return `"{escaped}"`
end

function Encoders.table(value: Types.DataNull | Types.DataArray | Types.DataMap, level: number): string
	if value.kind == "null" then
		return "nil"
	end

	if value.kind == "array" then
		local items = {}

		for _, item in value.items do
			table.insert(items, encodeValue(item, level))
		end

		return `\{{table.concat(items, ", ")}}`
	end

	local indent = string.rep("\t", level + 1)
	local lines = {}

	for _, entry in value.entries do
		table.insert(lines, `{indent}{encodeKey(entry.key, level + 1)} = {encodeValue(entry.value, level + 1)},\n`)
	end

	return `\{\n{table.concat(lines)}{string.rep("\t", level)}}`
end

--[[
	Generates the source of the `ModuleScript` Rojo 7.7.1 builds from a data file: `return` and `value` as Luau,
		with no trailing newline, arrays on one line, maps a line per entry indented with tabs, and an identifier
		key written bare while every other key is bracketed.
]]
return function(value: Types.DataValue): string
	return `return {encodeValue(value, 0)}`
end
