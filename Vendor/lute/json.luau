--!strict
--!native
-- @std/json
-- JSON serialization and deserialization library

local json = {
	--- A sentinel value representing JSON `null`. Not actually `nil` — use this when you need to serialize a null field.
	null = newproxy() :: nil,
}

--- A JSON object: a table with string keys.
export type Object = { [string]: Value }
--- A JSON array: a table with integer keys.
export type Array = { [number]: Value }
--- Any JSON value: `null`, a number, string, boolean, array, or object.
export type Value = nil | number | string | boolean | Array | Object

--- Wally-Plugin addition: a value from the order-keeping mode. Objects are maps whose entries are sorted by key bytes
--- (duplicate keys last-wins), arrays keep their items, and `null` is a value of its own.
export type OrderedValue =
	boolean
	| number
	| string
	| { kind: "null" }
	| { kind: "array", items: { OrderedValue } }
	| { kind: "map", entries: { { key: string, value: OrderedValue } } }

--- Wally-Plugin addition: options for `json.deserialize`. `jsonc` accepts Rojo 7.7.1's JSON dialect (jsonc-parser
--- 0.27.1 with its default options); `ordered` returns `OrderedValue` shapes. Both default to off, which is upstream's
--- strict parser unchanged.
export type DeserializeOptions = {
	jsonc: boolean?,
	ordered: boolean?,
}

-- a unique key to identify an object vs a table
local object_key = newproxy()

-- serialization

local bufferSize = 0
local keyCacheLimit = 128
local keyCacheKeySizeLimit = 64

type SerializerState = {
	buf: buffer,
	cursor: number,
	prettyPrint: boolean,
	depth: number,
	-- Per-serialize-call cache of escaped object keys, including their colon separator.
	keyCache: { [string]: string },
	keyCacheCount: number,
}

local function growBuffer(state: SerializerState, curLen: number): ()
	local newBuffer = buffer.create(curLen)

	buffer.copy(newBuffer, 0, state.buf)

	state.buf = newBuffer
end

local function checkState(state: SerializerState, len: number): ()
	local cursor = state.cursor
	local requiredLen = cursor + len
	local bits = bit32.countlz(requiredLen)

	if bit32.countlz(cursor) == bits then
		return
	end

	growBuffer(state, 2 ^ (32 - bits))
end

local function writeByte(state: SerializerState, byte: number): ()
	checkState(state, 1)

	buffer.writeu8(state.buf, state.cursor, byte)

	state.cursor += 1
end

local function writeSpaces(state: SerializerState): ()
	if not state.prettyPrint or state.depth == 0 then
		return
	end

	checkState(state, state.depth * 4)

	for _ = 1, state.depth do
		buffer.writeu32(state.buf, state.cursor, 0x_20_20_20_20)
		state.cursor += 4
	end
end

local function writeString(state: SerializerState, str: string): ()
	local sl = #str
	checkState(state, sl)

	local cursor = state.cursor
	buffer.writestring(state.buf, cursor, str)

	state.cursor = cursor + sl
end

local serializeAny: (SerializerState, (Array | Object | boolean | number | string)?) -> ()

local STRING_ESCAPES: { [string]: string } = {
	["\\"] = "\\\\",
	['"'] = '\\"',
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}
for i = 0, 31 do
	local c = string.char(i)
	if not STRING_ESCAPES[c] then
		STRING_ESCAPES[c] = string.format("\\u%04x", i)
	end
end

local STRING_NEEDS_ESCAPE = '[%z\1-\31"\\]'

local function serializeString(state: SerializerState, str: string): ()
	local escaped = if string.find(str, STRING_NEEDS_ESCAPE)
		then string.gsub(str, STRING_NEEDS_ESCAPE, STRING_ESCAPES)
		else str

	local sl = #escaped
	checkState(state, sl + 2)
	local buf = state.buf
	local cursor = state.cursor
	buffer.writeu8(buf, cursor, 0x22)
	buffer.writestring(buf, cursor + 1, escaped)
	buffer.writeu8(buf, cursor + 1 + sl, 0x22)
	state.cursor = cursor + sl + 2
end

local function serializeKeyString(state: SerializerState, str: string): ()
	local cached = state.keyCache[str]
	if cached ~= nil then
		writeString(state, cached)
		return
	end

	local escaped: string
	if string.find(str, STRING_NEEDS_ESCAPE) then
		escaped = string.gsub(str, STRING_NEEDS_ESCAPE, STRING_ESCAPES)
	else
		escaped = str
	end
	cached = '"' .. escaped .. (if state.prettyPrint then '": ' else '":')
	if state.keyCacheCount < keyCacheLimit and #str <= keyCacheKeySizeLimit then
		state.keyCache[str] = cached
		state.keyCacheCount += 1
	end

	writeString(state, cached)
end

local function serializeArray(state: SerializerState, array: Array): ()
	state.depth += 1

	writeByte(state, string.byte("["))

	if state.prettyPrint and #array ~= 0 then
		writeByte(state, string.byte("\n"))
	end

	for i, value in array do
		if i ~= 1 then
			writeByte(state, string.byte(","))

			if state.prettyPrint then
				writeByte(state, string.byte("\n"))
			end
		end

		writeSpaces(state)

		serializeAny(state, value)
	end

	state.depth -= 1

	if state.prettyPrint and #array ~= 0 then
		writeByte(state, string.byte("\n"))
		writeSpaces(state)
	end

	writeByte(state, string.byte("]"))
end

local function serializeTable(state: SerializerState, object: Object): ()
	writeByte(state, string.byte("{"))

	if state.prettyPrint then
		writeByte(state, string.byte("\n"))
	end

	state.depth += 1

	local first = true
	for key, value in object do
		if key == object_key then
			continue
		end

		if not first then
			writeByte(state, string.byte(","))

			if state.prettyPrint then
				writeByte(state, string.byte("\n"))
			end
		end

		first = false

		writeSpaces(state)

		serializeKeyString(state, key)

		serializeAny(state, value)
	end

	if state.prettyPrint then
		writeByte(state, string.byte("\n"))
	end

	state.depth -= 1

	writeSpaces(state)

	writeByte(state, string.byte("}"))
end

serializeAny = function(state: SerializerState, value: Value): ()
	if value == json.null then
		writeString(state, "null")
	elseif typeof(value) == "boolean" then
		writeString(state, if value then "true" else "false")
	elseif typeof(value) == "number" then
		if not math.isfinite(value) then
			error("Cannot serialize non-finite number", 2)
		end

		writeString(state, tostring(value))
	elseif typeof(value) == "string" then
		serializeString(state, value)
	elseif typeof(value) == "table" then
		if #value == 0 and next(value :: { [unknown]: unknown }) ~= nil then
			serializeTable(state, value :: Object)
		else
			serializeArray(state, value :: Array)
		end
	else
		error("Unknown value", 2)
	end
end

-- deserialization

type DeserializerState = {
	src: string,
	cursor: number,
	ordered: boolean,
}

local function deserializerError(state: DeserializerState, msg: string): never
	return error(`JSON error - {msg} around {state.cursor}`)
end

local function skipWhitespace(state: DeserializerState): boolean
	local b = string.byte(state.src, state.cursor)
	if b == nil then
		return false
	end
	if b ~= 0x20 and b ~= 0x09 and b ~= 0x0A and b ~= 0x0D then
		return true
	end

	state.cursor = string.find(state.src, "[^ \n\r\t]", state.cursor) :: number
	if not state.cursor then
		return false
	end
	return true
end

local function currentByte(state: DeserializerState): number
	return (string.byte(state.src, state.cursor))
end

local function deserializeNumber(state: DeserializerState): number?
	local src = state.src
	local nStart = state.cursor
	local cursor = nStart
	local b = string.byte(src, cursor)
	local sign = 1
	local intValue = 0
	local digitCount = 0
	local isInteger = true

	if b == 0x2D then -- '-'
		sign = -1
		cursor += 1
		b = string.byte(src, cursor)
	end

	if b == 0x30 then -- '0'
		digitCount = 1
		cursor += 1
		b = string.byte(src, cursor)
		if b ~= nil and b >= 0x30 and b <= 0x39 then
			deserializerError(state, "Malformed number (leading zeros not allowed)")
		end
	elseif b ~= nil and b >= 0x31 and b <= 0x39 then
		repeat
			digitCount += 1
			if digitCount <= 15 then
				intValue = intValue * 10 + ((b :: number) - 0x30)
			end
			cursor += 1
			b = string.byte(src, cursor)
		until b == nil or b < 0x30 or b > 0x39
	else
		deserializerError(state, "Malformed number (bad integer part)")
	end

	if b == 0x2E then -- '.'
		isInteger = false
		cursor += 1
		b = string.byte(src, cursor)
		if b == nil or b < 0x30 or b > 0x39 then
			deserializerError(state, "Malformed number (bad decimal part)")
		end
		repeat
			cursor += 1
			b = string.byte(src, cursor)
		until b == nil or b < 0x30 or b > 0x39
	end

	if b == 0x65 or b == 0x45 then -- 'e' or 'E'
		isInteger = false
		cursor += 1
		b = string.byte(src, cursor)
		if b == 0x2B or b == 0x2D then -- '+' or '-'
			cursor += 1
			b = string.byte(src, cursor)
		end
		if b == nil or b < 0x30 or b > 0x39 then
			deserializerError(state, "Malformed number (bad exponent part)")
		end
		repeat
			cursor += 1
			b = string.byte(src, cursor)
		until b == nil or b < 0x30 or b > 0x39
	end

	if isInteger and digitCount <= 15 then
		state.cursor = cursor
		return sign * intValue
	end

	local num = tonumber(string.sub(src, nStart, cursor - 1))
	if not num then
		deserializerError(state, "Malformed number value")
	end

	state.cursor = cursor
	return num
end

local UNESCAPE: { [string]: string } = {
	['"'] = '"',
	["\\"] = "\\",
	["/"] = "/",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
}

-- Wally-Plugin addition: the order-keeping mode's shapes
local function orderedNull(): OrderedValue
	return { kind = "null" }
end

local function orderedMap(keys: { string }, values: { [string]: any }): OrderedValue
	table.sort(keys)

	local entries = table.create(#keys)
	for _, key in keys do
		table.insert(entries, { key = key, value = values[key] })
	end

	return { kind = "map", entries = entries }
end

local function decodeUnicodeEscape(hex: string, cursor: number): string
	local cp = tonumber(hex, 16) :: number
	if cp >= 0xD800 and cp <= 0xDBFF then
		error(`JSON error - Incomplete surrogate pair around {cursor}`)
	end
	if cp >= 0xDC00 and cp <= 0xDFFF then
		error(`JSON error - Lone low surrogate around {cursor}`)
	end
	return utf8.char(cp)
end

local function decodeSurrogatePair(highHex: string, lowHex: string, cursor: number): string
	local high = tonumber(highHex, 16) :: number
	local low = tonumber(lowHex, 16) :: number
	if low < 0xDC00 or low > 0xDFFF then
		error(`JSON error - Invalid unicode surrogate pair around {cursor}`)
	end
	local codepoint = 0x10000 + ((high - 0xD800) * 0x400) + (low - 0xDC00)
	return utf8.char(codepoint)
end

local function deserializeString(state: DeserializerState): string
	if currentByte(state) ~= string.byte('"') then
		return deserializerError(state, "Expected string opening quote")
	end

	local startPos = state.cursor + 1
	local src = state.src

	local p = string.find(src, '[\\"%z\1-\31]', startPos)
	if not p then
		return deserializerError(state, "Unterminated string")
	end
	local b = string.byte(src, p)
	if b == 0x22 then
		state.cursor = p + 1
		return string.sub(src, startPos, p - 1)
	end
	if b ~= 0x5C then
		state.cursor = p
		return deserializerError(state, "Unescaped control character in string")
	end

	local len = #src
	while p <= len do
		local c = string.byte(src, p)
		if c == 0x5C then
			p += 2
		elseif c == 0x22 then
			break
		elseif c < 0x20 then
			state.cursor = p
			return deserializerError(state, "Unescaped control character in string")
		else
			p += 1
		end
	end
	if p > len then
		return deserializerError(state, "Unterminated string")
	end

	local raw = string.sub(src, startPos, p - 1)
	local cursor = state.cursor

	-- Freeze raw `\\` as 0x01 so a `\\u0000` source isn't mis-parsed as
	-- backslash + `\u0000`. The scan above guarantees no 0x01 in input.
	raw = string.gsub(raw, "\\\\", "\1")
	raw = string.gsub(
		raw,
		"\\u([dD][89aAbB]%x%x)\\u([dD][c-fC-F]%x%x)",
		function(h, l)
			return decodeSurrogatePair(h, l, cursor)
		end :: any
	)
	raw = string.gsub(raw, "\\u(%x%x%x%x)", function(code)
		return decodeUnicodeEscape(code, cursor)
	end)
	raw = string.gsub(raw, "\\(.)", function(esc)
		local v = UNESCAPE[esc]
		if not v then
			error(`JSON error - Invalid escape sequence around {cursor}`)
		end
		return v
	end)
	raw = string.gsub(raw, "\1", "\\")

	state.cursor = p + 1
	return raw
end

local deserialize: (DeserializerState) -> (Array | Object | boolean | number | string)?

local function deserializeArray(state: DeserializerState): Array
	if currentByte(state) ~= string.byte("[") then
		return deserializerError(state, "Expected array opening '['")
	end

	state.cursor += 1
	skipWhitespace(state)

	local current: Array = {}
	local index = 1

	-- empty array
	if currentByte(state) == string.byte("]") then
		state.cursor += 1
		return current
	end

	local expectingValue = true

	while state.cursor <= #state.src do
		if not expectingValue then
			-- Expect a comma or closing bracket
			if currentByte(state) == string.byte(",") then
				expectingValue = true
				state.cursor += 1
				if not skipWhitespace(state) then
					return deserializerError(state, "Unterminated array")
				end
			elseif currentByte(state) == string.byte("]") then
				state.cursor += 1
				return current
			else
				return deserializerError(state, "Expected ',' or ']' after array value")
			end
		else
			-- Expect a value next
			if currentByte(state) == string.byte("]") then
				if index == 1 then
					-- empty array is ok
					state.cursor += 1
					return current
				else
					return deserializerError(state, "Trailing comma in array")
				end
			end

			table.insert(current, deserialize(state))
			index += 1
			expectingValue = false
		end

		if not skipWhitespace(state) then
			return deserializerError(state, "Unterminated array")
		end
	end

	return deserializerError(state, "Unterminated array")
end

local function deserializeObject(state: DeserializerState): Object
	state.cursor += 1

	local current = {}
	-- Wally-Plugin addition: first-seen keys, for the order-keeping mode
	local keys: { string } = {}

	local expectingValue = false
	while state.cursor < #state.src do
		skipWhitespace(state)

		if currentByte(state) == string.byte("}") then
			break
		end

		if currentByte(state) ~= string.byte('"') then
			return deserializerError(state, "Expected a string key")
		end

		local key = deserializeString(state)

		skipWhitespace(state)

		if currentByte(state) ~= string.byte(":") then
			return deserializerError(state, "Expected ':' for key value pair")
		end

		state.cursor += 1

		local value = deserialize(state)

		if state.ordered and current[key] == nil then
			table.insert(keys, key)
		end

		current[key] = value

		if not skipWhitespace(state) then
			deserializerError(state, "Unterminated object")
		end

		if currentByte(state) == string.byte(",") then
			expectingValue = true
			state.cursor += 1
		else
			expectingValue = false
		end
	end

	if expectingValue then
		return deserializerError(state, "Trailing comma")
	end

	if not skipWhitespace(state) or currentByte(state) ~= string.byte("}") then
		deserializerError(state, "Unterminated object")
	end

	state.cursor += 1

	if state.ordered then
		return orderedMap(keys, current) :: any
	end

	return current
end

deserialize = function(state: DeserializerState): Value
	skipWhitespace(state)

	local src = state.src
	local cursor = state.cursor
	local b = string.byte(src, cursor)

	if b == 0x22 then -- '"'
		return deserializeString(state)
	elseif b == 0x7B then -- '{'
		local obj = deserializeObject(state)
		if not state.ordered then
			obj[object_key] = true
		end
		return obj
	elseif b == 0x5B then -- '['
		local array = deserializeArray(state)
		if state.ordered then
			return { kind = "array", items = array } :: any
		end
		return array
	elseif b == 0x74 then -- 't' -> "true"
		local b1, b2, b3 = string.byte(src, cursor + 1, cursor + 3)
		if b1 == 0x72 and b2 == 0x75 and b3 == 0x65 then
			state.cursor = cursor + 4
			return true
		end
	elseif b == 0x66 then -- 'f' -> "false"
		local b1, b2, b3, b4 = string.byte(src, cursor + 1, cursor + 4)
		if b1 == 0x61 and b2 == 0x6C and b3 == 0x73 and b4 == 0x65 then
			state.cursor = cursor + 5
			return false
		end
	elseif b == 0x6E then -- 'n' -> "null"
		local b1, b2, b3 = string.byte(src, cursor + 1, cursor + 3)
		if b1 == 0x75 and b2 == 0x6C and b3 == 0x6C then
			state.cursor = cursor + 4
			return if state.ordered then orderedNull() :: any else json.null
		end
	elseif b == 0x2D or (b ~= nil and b >= 0x30 and b <= 0x39) then
		return deserializeNumber(state)
	end

	return deserializerError(state, `Unexpected token '{string.sub(src, cursor, cursor)}'`)
end

-- JSONC deserialization (Wally-Plugin addition)
--
-- Rojo 7.7.1 reads every JSON file through jsonc-parser 0.27.1 with its default options, then serde_json. This ports
-- that scanner (src/scanner.rs, src/string.rs), parser (src/parse_to_ast.rs) and number conversion (src/ast.rs):
-- `//` and `/* */` comments anywhere between tokens; a comma after an object property or array element is optional,
-- so trailing commas pass and so do missing ones; object keys may be strings, words or number literals (kept as
-- written); strings may be single-quoted and may hold raw control characters; numbers may carry a leading `+` and may
-- be hexadecimal (converted to an integer); a number serde_json cannot hold (beyond i64 for hexadecimal, not finite
-- for decimal) becomes the literal's text. Whitespace is Rust's `char::is_whitespace`, matched exactly; words are
-- `char::is_alphanumeric`, `-` and `_`, where every non-ASCII character that is not whitespace counts as alphanumeric.

type JsoncState = {
	src: string,
	cursor: number,
	ordered: boolean,
	token: string,
	tokenStart: number,
	tokenText: any,
}

local JSONC_PUNCTUATION: { [number]: string } = {
	[0x7B] = "{",
	[0x7D] = "}",
	[0x5B] = "[",
	[0x5D] = "]",
	[0x2C] = ",",
	[0x3A] = ":",
}

local JSONC_KEYWORDS: { { word: string, token: string, value: boolean? } } = {
	{ word = "true", token = "boolean", value = true },
	{ word = "false", token = "boolean", value = false },
	{ word = "null", token = "null" },
}

local JSONC_ESCAPES: { [number]: string } = {
	[0x5C] = "\\",
	[0x2F] = "/",
	[0x62] = "\b",
	[0x66] = "\f",
	[0x6E] = "\n",
	[0x72] = "\r",
	[0x74] = "\t",
}

local JSONC_UNEXPECTED: { [string]: string } = {
	["]"] = "Unexpected close bracket",
	["}"] = "Unexpected close brace",
	[","] = "Unexpected comma",
	[":"] = "Unexpected colon",
	word = "Unexpected word",
}

local function jsoncError(state: JsoncState, msg: string, at: number?): never
	return error(`JSON error - {msg} around {at or state.tokenStart}`)
end

-- byte length of the `char::is_whitespace` character at `cursor`, or 0
local function jsoncWhitespaceLength(src: string, cursor: number): number
	local b = string.byte(src, cursor)
	if b == nil then
		return 0
	end

	if b == 0x20 or (b >= 0x09 and b <= 0x0D) then
		return 1
	end

	if b == 0xC2 then
		local b2 = string.byte(src, cursor + 1)
		return if b2 == 0x85 or b2 == 0xA0 then 2 else 0
	end

	if b == 0xE1 or b == 0xE3 then
		local char = string.sub(src, cursor, cursor + 2)
		return if char == "\u{1680}" or char == "\u{3000}" then 3 else 0
	end

	if b == 0xE2 then
		local b2, b3 = string.byte(src, cursor + 1, cursor + 2)
		if b2 == 0x80 and b3 ~= nil and ((b3 >= 0x80 and b3 <= 0x8A) or b3 == 0xA8 or b3 == 0xA9 or b3 == 0xAF) then
			return 3
		end

		return if b2 == 0x81 and b3 == 0x9F then 3 else 0
	end

	return 0
end

local function isJsoncAlphanumeric(src: string, cursor: number): boolean
	local b = string.byte(src, cursor)
	if b == nil then
		return false
	end

	if b >= 0x80 then
		return jsoncWhitespaceLength(src, cursor) == 0
	end

	return (b >= 0x30 and b <= 0x39) or (b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A)
end

local function isAsciiDigit(b: number?): boolean
	return b ~= nil and b >= 0x30 and b <= 0x39
end

local function isAsciiHexDigit(b: number?): boolean
	return b ~= nil and ((b >= 0x30 and b <= 0x39) or (b >= 0x41 and b <= 0x46) or (b >= 0x61 and b <= 0x66))
end

local function jsoncSkipWhitespace(state: JsoncState): ()
	local src = state.src

	while true do
		state.cursor = string.find(src, "[^\t\n\v\f\r ]", state.cursor) or (#src + 1)

		local length = jsoncWhitespaceLength(src, state.cursor)
		if length == 0 then
			return
		end

		state.cursor += length
	end
end

local function jsoncHex4(state: JsoncState, at: number): number
	local hex = string.sub(state.src, at, at + 3)
	if not string.find(hex, "^%x%x%x%x$") then
		jsoncError(state, "Expected four hex digits", at)
	end

	return tonumber(hex, 16) :: number
end

local function jsoncScanString(state: JsoncState, quote: number): string
	local src = state.src
	local start = state.cursor
	local stopPattern = if quote == 0x22 then '[\\"]' else "[\\']"
	local parts = {}
	local cursor = start + 1

	while true do
		local p = string.find(src, stopPattern, cursor)
		if not p then
			return jsoncError(state, "Unterminated string literal", start)
		end

		table.insert(parts, string.sub(src, cursor, p - 1))

		if string.byte(src, p) == quote then
			state.cursor = p + 1
			return table.concat(parts)
		end

		local escape = string.byte(src, p + 1)
		cursor = p + 2

		if escape == nil then
			jsoncError(state, "Unterminated string literal", start)
		elseif escape == 0x22 or escape == 0x27 then
			if escape ~= quote then
				jsoncError(
					state,
					if quote == 0x22
						then "Invalid escape in double quote string"
						else "Invalid escape in single quote string",
					p
				)
			end

			table.insert(parts, string.char(escape))
		elseif escape == 0x75 then -- 'u'
			local high = jsoncHex4(state, p + 2)
			cursor = p + 6

			if high >= 0xD800 and high <= 0xDBFF then
				if string.sub(src, p + 6, p + 7) ~= "\\u" then
					jsoncError(state, "Invalid unicode escape sequence (unpaired high surrogate)", p)
				end

				local low = jsoncHex4(state, p + 8)
				if low < 0xDC00 or low > 0xDFFF then
					jsoncError(state, "Invalid unicode escape sequence (high surrogate not followed by low surrogate)", p)
				end

				table.insert(parts, utf8.char(0x10000 + (high - 0xD800) * 0x400 + (low - 0xDC00)))
				cursor = p + 12
			elseif high >= 0xDC00 and high <= 0xDFFF then
				jsoncError(state, "Invalid unicode escape sequence (unpaired low surrogate)", p)
			else
				table.insert(parts, utf8.char(high))
			end
		elseif JSONC_ESCAPES[escape] then
			table.insert(parts, JSONC_ESCAPES[escape])
		else
			jsoncError(state, "Invalid escape", p)
		end
	end
end

local function jsoncScanNumber(state: JsoncState): string
	local src = state.src
	local start = state.cursor
	local cursor = start
	local b = string.byte(src, cursor)

	if b == 0x2D or b == 0x2B then -- '-' or '+'
		cursor += 1
		b = string.byte(src, cursor)
	end

	if b == 0x30 then -- '0'
		cursor += 1
		b = string.byte(src, cursor)

		if b == 0x78 or b == 0x58 then -- 'x' or 'X'
			cursor += 1
			if not isAsciiHexDigit(string.byte(src, cursor)) then
				jsoncError(state, "Expected digit", cursor)
			end

			while isAsciiHexDigit(string.byte(src, cursor)) do
				cursor += 1
			end

			state.cursor = cursor
			return string.sub(src, start, cursor - 1)
		end
	elseif b ~= nil and b >= 0x31 and b <= 0x39 then
		repeat
			cursor += 1
			b = string.byte(src, cursor)
		until not isAsciiDigit(b)
	else
		jsoncError(state, "Expected a digit to follow a negative sign", cursor)
	end

	if b == 0x2E then -- '.'
		cursor += 1
		if not isAsciiDigit(string.byte(src, cursor)) then
			jsoncError(state, "Expected digit", cursor)
		end

		repeat
			cursor += 1
			b = string.byte(src, cursor)
		until not isAsciiDigit(b)
	end

	if b == 0x65 or b == 0x45 then -- 'e' or 'E'
		cursor += 1
		b = string.byte(src, cursor)

		if b == 0x2B or b == 0x2D then
			cursor += 1
		end

		if not isAsciiDigit(string.byte(src, cursor)) then
			jsoncError(state, "Expected plus, minus, or digit in number literal", cursor)
		end

		repeat
			cursor += 1
		until not isAsciiDigit(string.byte(src, cursor))
	end

	state.cursor = cursor
	return string.sub(src, start, cursor - 1)
end

-- moves to the next token, skipping comments, and leaves its kind in `state.token`
local function jsoncScan(state: JsoncState): ()
	local src = state.src

	while true do
		jsoncSkipWhitespace(state)

		local cursor = state.cursor
		local b = string.byte(src, cursor)
		state.tokenStart = cursor
		state.tokenText = nil

		if b == nil then
			state.token = "eof"
			return
		end

		local punctuation = JSONC_PUNCTUATION[b]
		if punctuation then
			state.token = punctuation
			state.cursor = cursor + 1
			return
		end

		if b == 0x22 or b == 0x27 then
			state.token = "string"
			state.tokenText = jsoncScanString(state, b)
			return
		end

		if b == 0x2F then -- '/'
			local nextByte = string.byte(src, cursor + 1)

			if nextByte == 0x2F then
				state.cursor = string.find(src, "\n", cursor + 2, true) or (#src + 1)
				continue
			end

			if nextByte == 0x2A then
				local close = string.find(src, "*/", cursor + 2, true)
				if not close then
					jsoncError(state, "Unterminated comment block")
				end

				state.cursor = close + 2
				continue
			end

			jsoncError(state, "Unexpected token")
		end

		if b == 0x2D or b == 0x2B or isAsciiDigit(b) then
			state.token = "number"
			state.tokenText = jsoncScanNumber(state)
			return
		end

		for _, keyword in JSONC_KEYWORDS do
			local wordEnd = cursor + #keyword.word
			if string.sub(src, cursor, wordEnd - 1) == keyword.word and not isJsoncAlphanumeric(src, wordEnd) then
				state.token = keyword.token
				state.tokenText = keyword.value
				state.cursor = wordEnd
				return
			end
		end

		local wordEnd = cursor
		while wordEnd <= #src do
			local wb = string.byte(src, wordEnd)
			if wb == 0x3A or jsoncWhitespaceLength(src, wordEnd) > 0 then
				break
			end

			if not (wb == 0x2D or wb == 0x5F or isJsoncAlphanumeric(src, wordEnd)) then
				jsoncError(state, "Unexpected token")
			end

			wordEnd += 1
		end

		if wordEnd == cursor then
			jsoncError(state, "Unexpected token")
		end

		state.token = "word"
		state.tokenText = string.sub(src, cursor, wordEnd - 1)
		state.cursor = wordEnd
		return
	end
end

local function jsoncNumberValue(text: string): number | string
	local unsigned = string.match(text, "^[+-]?(.*)$") :: string
	local prefix = string.sub(unsigned, 1, 2)

	if #unsigned > 2 and (prefix == "0x" or prefix == "0X") then
		local hex = string.sub(unsigned, 3)
		local significant = string.match(hex, "^0*(.*)$") :: string
		local leading = tonumber(string.sub(significant, 1, 1), 16)

		-- i64::from_str_radix fails beyond i64::MAX, and jsonc-parser then keeps the literal's text
		if #significant > 16 or (#significant == 16 and leading ~= nil and leading > 7) then
			return text
		end

		local value = tonumber(hex, 16) :: number
		return if string.byte(text, 1) == 0x2D then -value else value
	end

	local value = tonumber(if string.byte(text, 1) == 0x2B then string.sub(text, 2) else text) :: number
	if value == math.huge or value == -math.huge then
		return text
	end

	return value
end

local jsoncParseValue: (JsoncState) -> (boolean, any)

local function jsoncParseObject(state: JsoncState): any
	local values = {}
	local keys: { string } = {}

	jsoncScan(state)

	while true do
		local token = state.token
		if token == "}" then
			break
		end

		if token ~= "string" and token ~= "word" and token ~= "number" then
			jsoncError(state, if token == "eof" then "Unterminated object" else "Unexpected token in object")
		end

		local key = state.tokenText

		jsoncScan(state)
		if state.token ~= ":" then
			jsoncError(state, "Expected colon after the string or word in object property")
		end

		jsoncScan(state)
		local hasValue, value = jsoncParseValue(state)
		if not hasValue then
			jsoncError(state, "Expected value after colon in object property")
		end

		if values[key] == nil then
			table.insert(keys, key)
		end

		values[key] = value

		jsoncScan(state)
		if state.token == "," then
			jsoncScan(state)
		end
	end

	if state.ordered then
		return orderedMap(keys, values)
	end

	values[object_key] = true
	return values
end

local function jsoncParseArray(state: JsoncState): any
	local items = {}

	jsoncScan(state)

	while true do
		local token = state.token
		if token == "]" then
			break
		end

		if token == "eof" then
			jsoncError(state, "Unterminated array")
		end

		local _, value = jsoncParseValue(state)
		table.insert(items, value)

		jsoncScan(state)
		if state.token == "," then
			jsoncScan(state)
		end
	end

	if state.ordered then
		return { kind = "array", items = items }
	end

	return items
end

jsoncParseValue = function(state: JsoncState): (boolean, any)
	local token = state.token

	if token == "eof" then
		return false, nil
	elseif token == "{" then
		return true, jsoncParseObject(state)
	elseif token == "[" then
		return true, jsoncParseArray(state)
	elseif token == "string" or token == "boolean" then
		return true, state.tokenText
	elseif token == "number" then
		return true, jsoncNumberValue(state.tokenText)
	elseif token == "null" then
		return true, if state.ordered then orderedNull() else json.null
	end

	return jsoncError(state, JSONC_UNEXPECTED[token])
end

local function deserializeJsonc(src: string, ordered: boolean): any
	local state: JsoncState = {
		src = src,
		cursor = 1,
		ordered = ordered,
		token = "eof",
		tokenStart = 1,
		tokenText = nil,
	}

	jsoncScan(state)

	local hasValue, value = jsoncParseValue(state)
	if not hasValue then
		jsoncError(state, "File contains no JSON value")
	end

	jsoncScan(state)
	if state.token ~= "eof" then
		jsoncError(state, "Text cannot contain more than one JSON value")
	end

	return value
end

-- user-facing

--- Serializes `value` to a JSON string. If `prettyPrint` is `true`, the output is indented for readability.
function json.serialize(value: Value, prettyPrint: boolean?): string
	local state: SerializerState = {
		buf = buffer.create(bufferSize),
		cursor = 0,
		prettyPrint = prettyPrint or false,
		depth = 0,
		keyCache = {},
		keyCacheCount = 0,
	}

	serializeAny(state, value)

	return buffer.readstring(state.buf, 0, state.cursor)
end

--- Parses a JSON string and returns the corresponding Luau value. Returns `json.null` for a JSON `null` literal; compare with `json.null` rather than `nil` to check for null.
--- Wally-Plugin addition: `options` (see `DeserializeOptions`) enables Rojo's JSONC dialect and the order-keeping mode.
function json.deserialize(src: string, options: DeserializeOptions?): (Array | Object | boolean | number | string)?
	local jsonc = options ~= nil and options.jsonc == true
	local ordered = options ~= nil and options.ordered == true

	if jsonc then
		return deserializeJsonc(src, ordered)
	end

	local state = {
		src = src,
		cursor = 1,
		ordered = ordered,
	}

	local result = deserialize(state)

	-- After parsing a value, there must be no non-whitespace trailing characters.
	if skipWhitespace(state) then
		deserializerError(state, "Trailing characters after JSON value")
	end

	return result
end

--- Creates a JSON `Object` from `props`. Use this to distinguish an empty object `{}` from an empty array when serializing.
function json.object(props: { [string]: Value }): Object
	local res: Object = { [object_key] = true }

	for key, value in props do
		res[key] = value
	end

	return res
end

--- Returns `value` as an `Object` if it is a JSON object, or `nil` otherwise.
function json.asObject(value: Value): Object?
	if typeof(value) == "table" and value[object_key] then
		return value :: Object
	end

	return nil
end

--- Returns `value` as an `Array` if it is a JSON array, or `nil` otherwise.
function json.asArray(value: Value): Array?
	if typeof(value) == "table" and not value[object_key] then
		return value :: Array
	end

	return nil
end

return table.freeze(json)
