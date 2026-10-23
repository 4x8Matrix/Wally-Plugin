--[=[
	YAML encoding and decoding.

	Serialises Luau values to YAML text and parses YAML text back into
	Luau values.  Supports a practical subset of YAML 1.2 (block scalars,
	block/flow sequences and mappings, anchors & aliases, multi-line strings).

	```luau
	local yaml = require("@eryx/data/yaml")

	local str = yaml.encode({ name = "Alice", scores = {100, 97} })
	print(str)
	-- name: Alice
	-- scores:
	--   - 100
	--   - 97

	local tbl = yaml.decode("x: 1\ny: 2")
	print(tbl.x, tbl.y)  -- 1  2
	```

	**Mapping rules:**

	| Luau          | YAML             |
	|---------------|------------------|
	| `string`      | scalar           |
	| `number`      | scalar (numeric) |
	| `boolean`     | true / false     |
	| `nil`         | null / ~         |
	| Numeric table | sequence (- ...) |
	| Mixed table   | mapping (k: v)   |
]=]

local yaml = {}

-- ---------------------------------------------------------------------------
-- Encode
-- ---------------------------------------------------------------------------

--- Returns true when the table looks like a YAML sequence (contiguous 1..n keys).
local function isSequence(t: { [any]: any }): boolean
	local n = #t
	if n == 0 then
		return next(t) == nil
	end
	local count = 0
	for _ in t do
		count += 1
		if count > n then
			return false
		end
	end
	return count == n
end

--- Characters that force a YAML string to be quoted.
local NEEDS_QUOTE_PATTERN = "[:%#{%}%[%],&*?|%-><!%%@`\"'\n\r\t]"

--- YAML keywords that must be quoted when used as scalars.
local YAML_KEYWORDS: { [string]: boolean } = {
	["true"] = true,
	["false"] = true,
	["True"] = true,
	["False"] = true,
	["TRUE"] = true,
	["FALSE"] = true,
	["yes"] = true,
	["no"] = true,
	["Yes"] = true,
	["No"] = true,
	["YES"] = true,
	["NO"] = true,
	["on"] = true,
	["off"] = true,
	["On"] = true,
	["Off"] = true,
	["ON"] = true,
	["OFF"] = true,
	["null"] = true,
	["Null"] = true,
	["NULL"] = true,
	["~"] = true,
	[".inf"] = true,
	[".Inf"] = true,
	[".INF"] = true,
	["-.inf"] = true,
	["-.Inf"] = true,
	["-.INF"] = true,
	[".nan"] = true,
	[".NaN"] = true,
	[".NAN"] = true,
}

local function yamlEscapeString(s: string): string
	-- Use double-quoted style with standard escape sequences
	local escaped = s:gsub("\\", "\\\\")
		:gsub('"', '\\"')
		:gsub("\n", "\\n")
		:gsub("\r", "\\r")
		:gsub("\t", "\\t")
		:gsub("\b", "\\b")
		:gsub("\0", "\\0")
	return '"' .. escaped .. '"'
end

local function needsQuoting(s: string): boolean
	if #s == 0 then
		return true
	end
	if YAML_KEYWORDS[s] then
		return true
	end
	-- Starts/ends with whitespace
	if string.byte(s, 1) == 0x20 or string.byte(s, #s) == 0x20 then
		return true
	end
	-- Could be parsed as a number
	if tonumber(s) ~= nil then
		return true
	end
	-- Contains special characters
	if string.find(s, NEEDS_QUOTE_PATTERN) then
		return true
	end
	return false
end

local function encodeScalar(v: any): string
	local t = type(v)
	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return if v then "true" else "false"
	elseif t == "number" then
		if v ~= v then
			return ".nan"
		elseif v == math.huge then
			return ".inf"
		elseif v == -math.huge then
			return "-.inf"
		elseif v == math.floor(v) and math.abs(v) < 2 ^ 53 then
			return string.format("%d", v)
		else
			return string.format("%.17g", v)
		end
	elseif t == "string" then
		if needsQuoting(v) then
			return yamlEscapeString(v)
		end
		return v
	else
		error("Cannot encode type '" .. t .. "' as YAML")
	end
end

export type EncodeOptions = {
	-- Indentation string (default `"  "` - two spaces).
	indent: string?,
	-- Sort mapping keys alphabetically.
	sortKeys: boolean?,
	-- Use flow (inline) style for nested structures.
	flowLevel: number?,
}

local function encodeValue(v: any, opts: EncodeOptions, depth: number, buf: { string }, inline: boolean)
	local indentStr = opts.indent or "  "
	local sortKeys = opts.sortKeys or false
	local flowLevel = opts.flowLevel or math.huge

	local t = type(v)

	if t ~= "table" then
		table.insert(buf, encodeScalar(v))
		return
	end

	local asFlow = depth >= flowLevel

	-- Sequence
	if isSequence(v) then
		if #(v :: { any }) == 0 then
			table.insert(buf, "[]")
			return
		end

		if asFlow or inline then
			-- Flow sequence: [a, b, c]
			table.insert(buf, "[")
			for i = 1, #v do
				if i > 1 then
					table.insert(buf, ", ")
				end
				encodeValue(v[i], opts, depth + 1, buf, true)
			end
			table.insert(buf, "]")
			return
		end

		-- Block sequence
		for i = 1, #v do
			if i > 1 or depth > 0 then
				table.insert(buf, "\n" .. string.rep(indentStr, depth))
			end
			table.insert(buf, "- ")
			local child = v[i]
			if type(child) == "table" then
				if isSequence(child) then
					if #child == 0 then
						table.insert(buf, "[]")
					else
						encodeValue(child, opts, depth + 1, buf, false)
					end
				else
					-- Mapping as block under sequence item
					table.insert(buf, "\n")
					encodeValue(child, opts, depth + 1, buf, false)
					-- remove trailing newline that encode_value might add
				end
			else
				encodeValue(child, opts, depth + 1, buf, false)
			end
		end
		return
	end

	-- Mapping
	local keys: { string } = {}
	for k in v :: any do
		if type(k) ~= "string" and type(k) ~= "number" then
			error("YAML mapping keys must be strings or numbers, got " .. type(k))
		end
		table.insert(keys, tostring(k))
	end

	if #keys == 0 then
		table.insert(buf, "{}")
		return
	end

	if sortKeys then
		table.sort(keys)
	end

	if asFlow or inline then
		-- Flow mapping: {a: 1, b: 2}
		table.insert(buf, "{")
		for i, k in keys do
			if i > 1 then
				table.insert(buf, ", ")
			end
			local rawKey: any = k
			-- Try to use original key type
			if (v :: any)[k] == nil and tonumber(k) ~= nil then
				rawKey = tonumber(k)
			end
			table.insert(buf, encodeScalar(k))
			table.insert(buf, ": ")
			encodeValue((v :: any)[rawKey], opts, depth + 1, buf, true)
		end
		table.insert(buf, "}")
		return
	end

	-- Block mapping
	for i, k in keys do
		local rawKey: any = k
		if (v :: any)[k] == nil and tonumber(k) ~= nil then
			rawKey = tonumber(k)
		end

		if i > 1 or depth > 0 then
			table.insert(buf, "\n" .. string.rep(indentStr, depth))
		end

		table.insert(buf, encodeScalar(k))
		table.insert(buf, ":")

		local child = (v :: any)[rawKey]
		if type(child) == "table" then
			local childIsSeq = isSequence(child)
			if childIsSeq and #(child :: { any }) == 0 then
				table.insert(buf, " []")
			elseif not childIsSeq and next(child) == nil then
				table.insert(buf, " {}")
			else
				table.insert(buf, "\n")
				encodeValue(child, opts, depth + 1, buf, false)
			end
		else
			table.insert(buf, " ")
			encodeValue(child, opts, depth + 1, buf, false)
		end
	end
end

--[=[
	Encodes a Luau value as a YAML string.

	Tables with sequential integer keys (1 .. n) are encoded as YAML sequences.
	Tables with string keys are encoded as YAML mappings. Nested structures
	are fully supported.

	```luau
	local yaml = require("@eryx/data/yaml")
	print(yaml.encode({ a = 1, b = { 2, 3 } }))
	-- a: 1
	-- b:
	--   - 2
	--   - 3
	```

	@param value -- The value to encode.
	@param options EncodeOptions? -- Optional formatting options.
	@return string -- The YAML string.
]=]
function yaml.encode(value: any, options: EncodeOptions?): string
	local opts: EncodeOptions = options or {} :: any
	local buf: { string } = {}
	encodeValue(value, opts, 0, buf, false)
	return table.concat(buf)
end

-- ---------------------------------------------------------------------------
-- Decode
-- ---------------------------------------------------------------------------

-- Wally-Plugin change: the decoder below reads YAML as yaml-rust2 0.10.4 reads it (`YamlLoader::load_from_str`,
-- the parser Rojo 7.7.1 uses), on the structure eryx wrote: the text is split into lines once, block
-- collections are read line by line, and flow collections and scalars are read character by character.
-- Values are DataValues: a mapping is `{ kind = "map", entries = { { key = ..., value = ... } } }` in written
-- order with keys of any type, a sequence `{ kind = "array", items = { ... } }`, a null `{ kind = "null" }`.
-- Every change is listed in NOTICE.md and marked `Wally-Plugin change` here.

type Line = {
	indent: number,
	text: string,
	raw: string,
	-- Wally-Plugin change: where the line starts in the document's text
	start: number,
}

-- Wally-Plugin addition: an anchor and a tag read before a node, and the column the first of them starts at
type Properties = {
	anchor: string?,
	tag: { handle: string, suffix: string }?,
	column: number?,
}

type ParseState = {
	lines: { Line },
	pos: number, -- current line index (1-based)
	anchors: { [string]: any },
	-- Wally-Plugin change: the document's text, the values anchored so far by anchor id (yaml-rust2 numbers
	-- every anchor), the handles the document's %TAG directive declared, whether the document ends the
	-- stream, the keys each mapping holds, and the first value Rojo cannot convert
	source: string,
	values: { [number]: { value: any, identity: string? } },
	anchorCount: number,
	tags: { [string]: string },
	streamEnd: boolean,
	keys: { [any]: { [string]: boolean } },
	problem: string?,
	flowIndent: number,
}

local YAML_TAG_PREFIX = "tag:yaml.org,2002:"
local BAD_VALUE = "Rojo cannot convert YAML to Luau because of a parsing error"
local LIMB = 16777216 -- integers are read into three base 2^24 limbs, least significant first
local BOM = "\u{FEFF}"

-- yaml-rust2's `BadValue`, which leaves a mapping's key slot empty and which Rojo refuses anywhere else
local BAD_NODE = table.freeze({ kind = "bad" })

local function newNull(): any
	return { kind = "null" }
end

local function newArray(): any
	return { kind = "array", items = {} }
end

local function newMap(): any
	return { kind = "map", entries = {} }
end

-- Wally-Plugin addition: an alias stands for a copy of its anchored node, as yaml-rust2's loader clones it
local function copyValue(value: any): any
	if type(value) ~= "table" or value == BAD_NODE or value.kind == "integer" then
		return value
	end
	if value.kind == "array" then
		local copy = newArray()
		for _, item in value.items do
			table.insert(copy.items, copyValue(item))
		end
		return copy
	elseif value.kind == "map" then
		local copy = newMap()
		for _, entry in value.entries do
			table.insert(copy.entries, { key = copyValue(entry.key), value = copyValue(entry.value) })
		end
		return copy
	end
	return newNull()
end

local function isBlank(c: string): boolean
	return c == " " or c == "\t"
end

local function isBlankOrEnd(c: string): boolean
	return c == " " or c == "\t" or c == "\n" or c == ""
end

local function isFlowIndicator(c: string): boolean
	return c == "," or c == "[" or c == "]" or c == "{" or c == "}"
end

-- yaml-rust2's `Debug` text for a string key, which its duplicated key message prints
local function stringIdentity(s: string): string
	return 'String("' .. s:gsub("[\\\"]", "\\%0"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '")'
end

local function fail(message: string): never
	error(message, 0)
end

-- Records the first value Rojo's YAML-to-Luau conversion refuses; the stream itself is still valid YAML
local function recordProblem(state: ParseState, message: string)
	if state.problem == nil then
		state.problem = message
	end
end

-- Rojo's `yaml_to_luau` over a finished document, in its order (keys before values): a `BadValue` and an
-- integer above 2^53 are recorded as problems, and every node becomes a DataValue
local function finishValue(state: ParseState, value: any): any
	if type(value) ~= "table" then
		return value
	end
	if value == BAD_NODE then
		recordProblem(state, BAD_VALUE)
		return newNull()
	end
	if value.kind == "integer" then
		recordProblem(state, `the integer '{value.text}' cannot be losslessly converted into a Luau number`)
		return value.value
	end
	if value.kind == "array" then
		for index, item in value.items do
			value.items[index] = finishValue(state, item)
		end
	elseif value.kind == "map" then
		for _, entry in value.entries do
			entry.key = finishValue(state, entry.key)
			entry.value = finishValue(state, entry.value)
		end
	end
	return value
end

local function splitLines(s: string): { Line }
	local lines: { Line } = {}

	-- Wally-Plugin change: line ends are normalised once for the whole stream, by `yaml.decodeDocuments`

	local pos = 1
	while pos <= #s do
		local nl = s:find("\n", pos, true)
		local raw
		local start = pos
		if nl then
			raw = s:sub(pos, nl - 1)
			pos = nl + 1
		else
			raw = s:sub(pos)
			pos = #s + 1
		end

		-- Calculate indent
		local leading = raw:match("^( *)") or ""
		local indent = #leading

		-- Wally-Plugin change: only spaces and tabs are YAML whitespace
		local text = raw:match("^(.-)[ \t]*$") or ""

		table.insert(lines, { indent = indent, text = text, raw = raw, start = start })
	end

	return lines
end

-- Wally-Plugin change: a comment line is one whose first non-blank character is `#`
local function isBlankOrCommentLine(line: Line): boolean
	return line.raw:find("^[ \t]*$") ~= nil or line.raw:find("^[ \t]*#") ~= nil
end

-- Wally-Plugin addition: the 0-based column of `offset` in the document's text
local function lineAt(state: ParseState, offset: number): number
	local low, high = 1, #state.lines
	if offset > #state.source then
		return #state.lines + 1
	end
	while low < high do
		local middle = (low + high + 1) // 2
		if state.lines[middle].start <= offset then
			low = middle
		else
			high = middle - 1
		end
	end
	return low
end

local function columnAt(state: ParseState, offset: number): number
	local index = lineAt(state, offset)
	if index > #state.lines then
		return 0
	end
	return offset - state.lines[index].start
end

-------------------------------------------------------------------------------
-- Wally-Plugin change: scalar resolution, ported from yaml-rust2 0.10.4's `Yaml::from_str` and `parse_f64`
-- (src/yaml.rs), with Rojo 7.7.1's refusal of integers above 2^53 (`yaml_to_luau` in
-- src/snapshot_middleware/yaml.rs) recorded as a problem. Each resolver returns the value and the key identity
-- yaml-rust2 compares keys by.

-- Rust's `i64::from_str_radix`: an optional sign, then one or more digits of the radix, within i64's range.
-- Returns the magnitude's limbs and whether it is negative, or nil.
local function parseInteger(text: string, radix: number): ({ number }?, boolean)
	local negative = false
	local sign = text:sub(1, 1)
	if sign == "+" or sign == "-" then
		negative = sign == "-"
		text = text:sub(2)
	end
	local pattern = if radix == 16 then "^%x+$" elseif radix == 8 then "^[0-7]+$" else "^%d+$"
	if not text:find(pattern) then
		return nil, false
	end
	local limbs = { 0, 0, 0 }
	for i = 1, #text do
		local carry = tonumber(text:sub(i, i), 16) :: number
		for j = 1, 3 do
			local n = limbs[j] * radix + carry
			limbs[j] = n % LIMB
			carry = n // LIMB
		end
		if carry > 0 then
			return nil, false
		end
	end
	-- i64 holds magnitudes below 2^63, or 2^63 itself when negative; 2^63 is { 0, 0, 2^15 }
	local top = limbs[3]
	if top > 32768 or (top == 32768 and (limbs[2] > 0 or limbs[1] > 0 or not negative)) then
		return nil, false
	end
	if top == 0 and limbs[2] == 0 and limbs[1] == 0 then
		negative = false
	end
	return limbs, negative
end

local function limbsToDecimal(limbs: { number }): string
	local work = { limbs[1], limbs[2], limbs[3] }
	local digits = {}
	repeat
		local remainder = 0
		for j = 3, 1, -1 do
			local n = remainder * LIMB + work[j]
			work[j] = n // 10
			remainder = n % 10
		end
		table.insert(digits, 1, tostring(remainder))
	until work[1] == 0 and work[2] == 0 and work[3] == 0
	return table.concat(digits)
end

-- An i64 as Rojo converts it: `as f64`, which rounds once to the nearest double; above 2^53 (negative ones
-- are not checked) it stays an integer node until `finishValue` refuses it
local function integerValue(state: ParseState, limbs: { number }, negative: boolean): (any, string)
	local decimal = (if negative then "-" else "") .. limbsToDecimal(limbs)
	local top = limbs[3]
	local value = (top * LIMB + limbs[2]) * LIMB + limbs[1]
	if negative then
		value = -value
	end
	if not negative and (top > 32 or (top == 32 and (limbs[2] > 0 or limbs[1] > 0))) then
		return { kind = "integer", value = value, text = decimal }, `Integer({decimal})`
	end
	return value, `Integer({decimal})`
end

-- Rust's f64 grammar, which `parse_f64` applies only to text holding an ASCII digit (so Rust's own `inf` and
-- `nan` spellings stay strings): an optional sign, digits with at most one point and at least one digit, then
-- an optional exponent
local function isRustFloat(v: string): boolean
	local mantissa, exponent = v:match("^[%+%-]?([%d%.]*)(.*)$")
	if mantissa == nil then
		return false
	end
	if exponent ~= "" and not (exponent :: string):find("^[eE][%+%-]?%d+$") then
		return false
	end
	return (mantissa :: string):find("^%d+%.?%d*$") ~= nil or (mantissa :: string):find("^%.%d+$") ~= nil
end

local function parseFloat(v: string): number?
	if v == ".inf" or v == ".Inf" or v == ".INF" or v == "+.inf" or v == "+.Inf" or v == "+.INF" then
		return math.huge
	elseif v == "-.inf" or v == "-.Inf" or v == "-.INF" then
		return -math.huge
	elseif v == ".nan" or v == ".NaN" or v == ".NAN" then
		return 0 / 0
	elseif isRustFloat(v) then
		return tonumber((v:gsub("^%+", "")))
	end
	return nil
end

--- Resolve a plain scalar string to an appropriate Luau type.
-- Wally-Plugin change: yaml-rust2's `Yaml::from_str`, which resolves every untagged plain scalar
local function resolveScalar(state: ParseState, s: string): (any, string)
	local limbs, negative
	if s:sub(1, 2) == "0x" then
		limbs, negative = parseInteger(s:sub(3), 16)
	elseif s:sub(1, 2) == "0o" then
		limbs, negative = parseInteger(s:sub(3), 8)
	elseif s:sub(1, 1) == "+" then
		limbs, negative = parseInteger(s:sub(2), 10)
	end
	if limbs then
		return integerValue(state, limbs, negative)
	end
	if s == "" or s == "~" or s == "null" then
		return newNull(), "Null"
	elseif s == "true" or s == "True" or s == "TRUE" then
		return true, "Boolean(true)"
	elseif s == "false" or s == "False" or s == "FALSE" then
		return false, "Boolean(false)"
	end
	limbs, negative = parseInteger(s, 10)
	if limbs then
		return integerValue(state, limbs, negative)
	end
	local real = parseFloat(s)
	if real then
		return real, `Real("{s}")`
	end
	return s, stringIdentity(s)
end

-- Wally-Plugin addition: a plain scalar under a tag, as yaml-rust2's loader reads it. Only the core schema's
-- `bool`, `int`, `float` and `null` resolve; any other tag makes a string, and a value its tag cannot hold is
-- yaml-rust2's `BadValue`, which Rojo refuses.
local function resolveTagged(state: ParseState, s: string, tag: { handle: string, suffix: string }?): (any, string)
	if tag == nil then
		return resolveScalar(state, s)
	end
	if tag.handle ~= YAML_TAG_PREFIX then
		return s, stringIdentity(s)
	end
	local suffix = tag.suffix
	if suffix == "bool" then
		if s == "true" or s == "True" or s == "TRUE" then
			return true, "Boolean(true)"
		elseif s == "false" or s == "False" or s == "FALSE" then
			return false, "Boolean(false)"
		end
	elseif suffix == "int" then
		local limbs, negative = parseInteger(s, 10)
		if limbs then
			return integerValue(state, limbs, negative)
		end
	elseif suffix == "float" then
		local real = parseFloat(s)
		if real then
			return real, `Real("{s}")`
		end
	elseif suffix == "null" then
		if s == "~" or s == "null" then
			return newNull(), "Null"
		end
	else
		return s, stringIdentity(s)
	end
	return BAD_NODE, "BadValue"
end

-------------------------------------------------------------------------------
-- Wally-Plugin addition: anchors, aliases and tags, as yaml-rust2's parser and loader treat them. Every anchor
-- gets a new id when it is read; an alias stands for a copy of the value the latest anchor of its name was
-- set on, once that node is complete. An alias inside its own anchor's node is yaml-rust2's `BadValue`.

local function beginNode(state: ParseState, properties: Properties?): number?
	if properties and properties.anchor then
		state.anchorCount += 1
		state.anchors[properties.anchor] = state.anchorCount
		return state.anchorCount
	end
	return nil
end

local function endNode(state: ParseState, id: number?, value: any, identity: string?): (any, string?)
	if id then
		state.values[id] = { value = value, identity = identity }
	end
	return value, identity
end

local function resolveAlias(state: ParseState, name: string): (any, string?)
	local id = state.anchors[name]
	if id == nil then
		fail(`while parsing node, found unknown anchor '{name}'`)
	end
	local anchored = state.values[id]
	if anchored == nil then
		return BAD_NODE, "BadValue"
	end
	return copyValue(anchored.value), anchored.identity
end

-- The end of an anchor or alias name: anything but whitespace, a byte order mark and the flow indicators
local function scanAnchorName(s: string, position: number): number
	local p = position
	while p <= #s do
		local c = s:sub(p, p)
		if isBlankOrEnd(c) or isFlowIndicator(c) or s:sub(p, p + 2) == BOM then
			break
		end
		p += 1
	end
	if p == position then
		fail("while scanning an anchor or alias, did not find expected alphabetic or numeric character")
	end
	return p
end

local function isWordChar(c: string): boolean
	return c:find("^[%w%-]$") ~= nil
end

local function isUriChar(c: string): boolean
	return isWordChar(c) or (c ~= "" and ("#;/?:@&=+$,_.!~*'()[]%"):find(c, 1, true) ~= nil)
end

local function isTagChar(c: string): boolean
	return isUriChar(c) and not isFlowIndicator(c) and c ~= "!"
end

-- `%XX` escapes in a tag, decoded as yaml-rust2's `scan_uri_escapes` decodes one UTF-8 character
local function scanUriEscapes(s: string, position: number): (string, number)
	local p = position
	local bytes = {}
	local width = 0
	repeat
		local hex = s:match("^%%(%x%x)", p)
		if not hex then
			fail("while parsing a tag, did not find URI escaped octet")
		end
		local octet = tonumber(hex, 16) :: number
		if width == 0 then
			width = if octet < 0x80 then 1 elseif octet >= 0xC0 and octet < 0xE0 then 2 elseif octet >= 0xE0 and octet < 0xF0 then 3 elseif octet >= 0xF0 and octet < 0xF8 then 4 else 0
			if width == 0 then
				fail("while parsing a tag, found an incorrect leading UTF-8 octet")
			end
		elseif octet < 0x80 or octet >= 0xC0 then
			fail("while parsing a tag, found an incorrect trailing UTF-8 octet")
		end
		table.insert(bytes, string.char(octet))
		p += 3
		width -= 1
	until width == 0
	local decoded = table.concat(bytes)
	if utf8.len(decoded) == nil then
		fail("while parsing a tag, found an invalid UTF-8 codepoint")
	end
	return decoded, p
end

-- yaml-rust2's `scan_tag` and the parser's `resolve_tag`: returns the tag, its handle replaced by the prefix
-- the document declared for it (`!!` is `tag:yaml.org,2002:` unless declared), and the position after it
local function scanTag(state: ParseState, s: string, position: number, inFlow: boolean): ({ handle: string, suffix: string }, number)
	local p = position
	local handle = ""
	local suffix
	if s:sub(p + 1, p + 1) == "<" then
		p += 2
		local parts = {}
		while isUriChar(s:sub(p, p)) do
			if s:sub(p, p) == "%" then
				local decoded
				decoded, p = scanUriEscapes(s, p)
				table.insert(parts, decoded)
			else
				table.insert(parts, s:sub(p, p))
				p += 1
			end
		end
		if s:sub(p, p) ~= ">" then
			fail("while scanning a verbatim tag, did not find the expected '>'")
		end
		p += 1
		suffix = table.concat(parts)
	else
		local handleEnd = p + 1
		while isWordChar(s:sub(handleEnd, handleEnd)) or s:sub(handleEnd, handleEnd) == "_" do
			handleEnd += 1
		end
		if s:sub(handleEnd, handleEnd) == "!" then
			handleEnd += 1
		end
		handle = s:sub(p, handleEnd - 1)
		local parts = {}
		local length = #handle
		local named = #handle >= 2 and handle:sub(-1) == "!"
		if named then
			p = handleEnd
			length = 0
		else
			table.insert(parts, handle:sub(2))
			p = handleEnd
		end
		while isTagChar(s:sub(p, p)) do
			if s:sub(p, p) == "%" then
				local decoded
				decoded, p = scanUriEscapes(s, p)
				table.insert(parts, decoded)
			else
				table.insert(parts, s:sub(p, p))
				p += 1
			end
			length += 1
		end
		suffix = table.concat(parts)
		if named and length == 0 then
			fail("while parsing a tag, did not find expected tag URI")
		end
		if not named then
			handle = "!"
			if suffix == "" then
				handle = ""
				suffix = "!"
			end
		end
	end
	local after = s:sub(p, p)
	if not (isBlankOrEnd(after) or (inFlow and isFlowIndicator(after))) then
		fail("while scanning a tag, did not find expected whitespace or line break")
	end
	local resolved
	if handle == "!!" then
		resolved = state.tags["!!"] or YAML_TAG_PREFIX
	elseif handle == "" and suffix == "!" then
		resolved = state.tags[""] or ""
	elseif state.tags[handle] then
		resolved = state.tags[handle]
	elseif #handle >= 2 and handle:sub(1, 1) == "!" and handle:sub(-1) == "!" then
		fail("the handle wasn't declared")
	else
		resolved = handle
	end
	return { handle = resolved, suffix = suffix }, p
end

-- Reads an anchor and a tag, in either order, from `position` on a line; returns them and the position of the
-- first character after them and the blanks that follow
local function scanProperties(state: ParseState, s: string, position: number, inherited: Properties?): (Properties, number)
	local properties: Properties = {}
	local p = position
	while true do
		local c = s:sub(p, p)
		if c == "&" then
			if properties.anchor or (inherited and inherited.anchor) then
				fail("while parsing a node, did not find expected node content")
			end
			local nameEnd = scanAnchorName(s, p + 1)
			properties.anchor = s:sub(p + 1, nameEnd - 1)
			properties.column = properties.column or p - 1
			p = nameEnd
		elseif c == "!" then
			if properties.tag or (inherited and inherited.tag) then
				fail("while parsing a node, did not find expected node content")
			end
			local tag, tagEnd = scanTag(state, s, p, false)
			properties.tag = tag
			properties.column = properties.column or p - 1
			p = tagEnd
		else
			break
		end
		while isBlank(s:sub(p, p)) do
			p += 1
		end
	end
	return properties, p
end

local function mergeProperties(first: Properties?, second: Properties?): Properties
	return {
		anchor = (first and first.anchor) or (second and second.anchor),
		tag = (first and first.tag) or (second and second.tag),
	}
end

-- Wally-Plugin addition: a key is refused when its mapping already holds it, as yaml-rust2's loader refuses it
local function addEntry(state: ParseState, map: any, key: any, identity: string?, value: any)
	if identity and identity ~= "BadValue" then
		local seen = state.keys[map]
		if seen == nil then
			seen = {}
			state.keys[map] = seen
		end
		if seen[identity] then
			fail(`{identity}: duplicated key in mapping`)
		end
		seen[identity] = true
	end
	table.insert(map.entries, { key = key, value = value })
end

-- Wally-Plugin addition: yaml-rust2's loader fills a mapping one node at a time: a node goes into the key
-- slot while it is empty, and the next one is the value. A `BadValue` key leaves the slot empty, so the
-- value after it becomes a key, and a key left in the slot when the mapping ends is dropped.
type MapBuilder = { map: any, key: { value: any, identity: string? }? }

local function pushMapNode(state: ParseState, builder: MapBuilder, node: any, identity: string?)
	local key = builder.key
	if key == nil then
		if node ~= BAD_NODE then
			builder.key = { value = node, identity = identity }
		end
		return
	end
	builder.key = nil
	addEntry(state, builder.map, key.value, key.identity, node)
end

--- Parse a double-quoted scalar, handling escape sequences.
-- Wally-Plugin change: yaml-rust2's escapes (`resolve_flow_scalar_escape_sequence`); returns the character
-- the escape at `position` (its backslash) stands for and the position after it
local SIMPLE_ESCAPES: { [string]: string } = {
	["0"] = "\0",
	a = "\a",
	b = "\b",
	t = "\t",
	["\t"] = "\t",
	n = "\n",
	v = "\v",
	f = "\f",
	r = "\r",
	e = "\27",
	[" "] = " ",
	['"'] = '"',
	["/"] = "/",
	["\\"] = "\\",
	N = "\u{85}",
	_ = "\u{A0}",
	L = "\u{2028}",
	P = "\u{2029}",
}
local CODE_LENGTHS: { [string]: number } = { x = 2, u = 4, U = 8 }

local function parseDoubleQuoted(s: string, position: number): (string, number)
	local esc = s:sub(position + 1, position + 1)
	local simple = SIMPLE_ESCAPES[esc]
	if simple then
		return simple, position + 2
	end
	local length = CODE_LENGTHS[esc]
	if length == nil then
		fail("while parsing a quoted scalar, found unknown escape character")
	end
	local digits = s:sub(position + 2, position + 1 + length)
	if #digits < length or not digits:find("^%x+$") then
		fail("while parsing a quoted scalar, did not find expected hexadecimal number")
	end
	local code = tonumber(digits, 16) :: number
	if code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF) then
		fail("while parsing a quoted scalar, found invalid Unicode character escape code")
	end
	return utf8.char(code), position + 2 + length
end

-- Wally-Plugin change: the rest of a line after a node must be blanks and a comment, and a comment must follow
-- a blank
local function finishLine(state: ParseState, offset: number)
	local source = state.source
	local p = offset
	while isBlank(source:sub(p, p)) do
		p += 1
	end
	local c = source:sub(p, p)
	if c == "#" then
		if p == offset and offset > 1 and not isBlankOrEnd(source:sub(offset - 1, offset - 1)) then
			fail("comments must be separated from other tokens by whitespace")
		end
		p = source:find("\n", p, true) or #source + 1
	elseif c ~= "\n" and c ~= "" then
		fail("did not find expected key")
	end
	state.pos = lineAt(state, p) + (if p <= #source then 1 else 0)
end

--- Try to extract a quoted string starting at position `pos` in `s`.
-- Wally-Plugin change: yaml-rust2's `scan_flow_scalar` on the document's text, so a quoted scalar may span
-- lines (folded as YAML folds them). `offset` is its opening quote; `indent` is the column continuation lines
-- may not start before. Returns the value and the offset after the closing quote.
local function tryQuoted(state: ParseState, offset: number, indent: number, inFlow: boolean): (string, number)
	local source = state.source
	local single = source:sub(offset, offset) == "'"
	local quote = if single then "'" else '"'
	local parts = {}
	local leadingBreak, trailingBreaks, whitespaces = "", "", ""
	local p = offset + 1
	local startLine = lineAt(state, offset)

	while true do
		if p > #source then
			fail("while scanning a quoted scalar, found unexpected end of stream")
		end
		if columnAt(state, p) < indent then
			fail("invalid indentation in quoted scalar")
		end

		local leadingBlanks = false
		while p <= #source do
			local c = source:sub(p, p)
			if isBlankOrEnd(c) then
				break
			end
			if single and c == "'" then
				if source:sub(p + 1, p + 1) == "'" then
					table.insert(parts, "'")
					p += 2
				else
					break
				end
			elseif not single and c == '"' then
				break
			elseif not single and c == "\\" and source:sub(p + 1, p + 1) == "\n" then
				p += 2
				leadingBlanks = true
				break
			elseif not single and c == "\\" then
				local character
				character, p = parseDoubleQuoted(source, p)
				table.insert(parts, character)
			else
				table.insert(parts, c)
				p += 1
			end
		end

		if source:sub(p, p) == quote then
			break
		end

		while true do
			local c = source:sub(p, p)
			if isBlank(c) then
				if leadingBlanks then
					if c == "\t" and columnAt(state, p) < indent then
						fail("tab cannot be used as indentation")
					end
				else
					whitespaces ..= c
				end
				p += 1
			elseif c == "\n" then
				if leadingBlanks then
					trailingBreaks ..= "\n"
				else
					whitespaces = ""
					leadingBreak = "\n"
					leadingBlanks = true
				end
				p += 1
			else
				break
			end
		end

		if leadingBlanks then
			if leadingBreak == "" then
				table.insert(parts, trailingBreaks)
			elseif trailingBreaks == "" then
				table.insert(parts, " ")
			else
				table.insert(parts, trailingBreaks)
			end
			leadingBreak, trailingBreaks = "", ""
		else
			table.insert(parts, whitespaces)
			whitespaces = ""
		end
	end

	p += 1
	local q = p
	while isBlank(source:sub(q, q)) do
		q += 1
	end
	local after = source:sub(q, q)
	if after == "#" and q == p then
		fail("comments must be separated from other tokens by whitespace")
	elseif after == ":" then
		if not inFlow and lineAt(state, q) ~= startLine then
			fail("invalid trailing content after double-quoted scalar")
		end
	elseif not (after == "#" or after == "\n" or after == "" or (inFlow and (after == "," or after == "}" or after == "]"))) then
		fail("invalid trailing content after double-quoted scalar")
	end

	return table.concat(parts), p
end

-- Wally-Plugin addition: yaml-rust2's `scan_plain_scalar` on the document's text. `threshold` is the column a
-- continuation line in a block must reach. Returns the scalar's text, the offset it stopped at, and whether
-- it stopped at an indicator (a `:` and a blank, or a flow indicator in a flow) rather than at a comment, a
-- less indented line or the end.
local function readPlain(state: ParseState, offset: number, inFlow: boolean, threshold: number): (string, number, boolean)
	local source = state.source
	local parts = {}
	local leadingBreak, trailingBreaks, whitespaces = "", "", ""
	local leadingWhitespace = false
	local p = offset
	local stopPattern = if inFlow then "[ \t\n:,%[%]{}]" else "[ \t\n:]"

	if inFlow and columnAt(state, offset) < threshold then
		fail("invalid indentation in flow construct")
	end

	local function canBePlain(position: number): boolean
		local c = source:sub(position, position)
		if c == ":" then
			local n = source:sub(position + 1, position + 1)
			return not (isBlankOrEnd(n) or (inFlow and isFlowIndicator(n)))
		end
		return not (inFlow and isFlowIndicator(c))
	end

	while true do
		local c = source:sub(p, p)
		if c == "#" or c == "" then
			break
		end
		if inFlow and c == "-" and isFlowIndicator(source:sub(p + 1, p + 1)) then
			fail("plain scalar cannot start with '-' followed by ,[]{}")
		end

		if not isBlankOrEnd(c) and canBePlain(p) then
			if leadingWhitespace then
				if leadingBreak == "" then
					table.insert(parts, trailingBreaks)
				elseif trailingBreaks == "" then
					table.insert(parts, " ")
				else
					table.insert(parts, trailingBreaks)
				end
				leadingBreak, trailingBreaks = "", ""
				leadingWhitespace = false
			elseif whitespaces ~= "" then
				table.insert(parts, whitespaces)
				whitespaces = ""
			end
			-- the run of characters up to a blank or an indicator
			local runStart = p
			while true do
				local stop = source:find(stopPattern, p)
				if stop == nil then
					p = #source + 1
					break
				end
				p = stop
				if source:sub(stop, stop) == ":" and canBePlain(stop) then
					p = stop + 1
					continue
				end
				break
			end
			table.insert(parts, source:sub(runStart, p - 1))
		end

		c = source:sub(p, p)
		if not (isBlank(c) or c == "\n") then
			return table.concat(parts), p, c ~= ""
		end

		while true do
			c = source:sub(p, p)
			if isBlank(c) then
				if not leadingWhitespace then
					whitespaces ..= c
					p += 1
				elseif c == "\t" and columnAt(state, p) < threshold then
					local q = p
					while isBlank(source:sub(q, q)) do
						q += 1
					end
					if source:sub(q, q) == "#" then
						q = source:find("\n", q, true) or #source + 1
					end
					if not (source:sub(q, q) == "\n" or q > #source) then
						fail("while scanning a plain scalar, found a tab")
					end
					p = q
				else
					p += 1
				end
			elseif c == "\n" then
				if leadingWhitespace then
					trailingBreaks ..= "\n"
				else
					whitespaces = ""
					leadingBreak = "\n"
					leadingWhitespace = true
				end
				p += 1
			else
				break
			end
		end

		if not inFlow and columnAt(state, p) < threshold then
			break
		end
	end

	return table.concat(parts), p, false
end

-- Forward declarations
local parseNode: (state: ParseState, lineIndex: number, column: number, blockIndent: number, context: string, inherited: Properties?) -> (any, string?)
local parseFlow: (state: ParseState, offset: number, blockIndent: number, inherited: Properties?) -> (any, string?, number, string)

--- Skip blank lines and comment-only lines from state.pos onwards.
-- Wally-Plugin change: returns the first line from `from` holding more than blanks and a comment
local function skipBlanks(state: ParseState, from: number): number?
	local index = from
	while index <= #state.lines do
		if not isBlankOrCommentLine(state.lines[index]) then
			return index
		end
		index += 1
	end
	return nil
end

-- Wally-Plugin addition: a content line of a block collection may not be indented with a tab
local function checkTabs(line: Line)
	if line.raw:find("^ *\t") then
		fail("tabs disallowed within this context (block indentation)")
	end
end

--- Collect a block scalar (literal | or folded >).
-- Wally-Plugin change: yaml-rust2's `scan_block_scalar`, line by line: the header's chomping and indentation
-- indicators in either order and its comment, the indentation found from the first content line and the blank
-- lines before it, blank and comment-looking lines kept, folding that keeps more-indented lines, and the
-- end of the stream read as yaml-rust2 reads it. Leaves `state.pos` at the first line after the scalar.
local function parseBlockScalar(state: ParseState, lineIndex: number, column: number, blockIndent: number): string
	local header = state.lines[lineIndex].raw
	local literal = header:sub(column + 1, column + 1) == "|"
	local chomp = "clip"
	local increment = 0
	local p = column + 2

	local function readChomp()
		local c = header:sub(p, p)
		if c == "+" or c == "-" then
			chomp = if c == "+" then "keep" else "strip"
			p += 1
			return true
		end
		return false
	end

	local function readIncrement()
		local c = header:sub(p, p)
		if c:find("^%d$") then
			if c == "0" then
				fail("while scanning a block scalar, found an indentation indicator equal to 0")
			end
			increment = tonumber(c) :: number
			p += 1
		end
	end

	if readChomp() then
		readIncrement()
	else
		readIncrement()
		if increment > 0 then
			readChomp()
		end
	end

	local afterHeader = p
	while isBlank(header:sub(p, p)) do
		p += 1
	end
	if header:sub(p, p) == "#" then
		if p == afterHeader then
			fail("comments must be separated from other tokens by whitespace")
		end
	elseif p <= #header then
		fail("while scanning a block scalar, did not find expected comment or line break")
	end

	local lines = state.lines
	local index = lineIndex + 1
	local hasBreak = lineIndex < #lines or #state.source >= lines[lineIndex].start + #header
	local atEnd = index > #lines

	if not atEnd and lines[index].raw:sub(1, 1) == "\t" then
		fail("a block scalar content cannot start with a tab")
	end

	local indent = 0
	local trailingBreaks = ""
	local position = 0 -- the column reached on line `index`

	if increment > 0 then
		indent = if blockIndent >= 0 then blockIndent + increment else increment
	end

	-- Leading blank lines; `position` is the column the first line holding more reaches
	local maxIndent = 0
	while index <= #lines do
		local raw = lines[index].raw
		local spaces = #(raw:match("^( *)") :: string)
		local consumed = if increment > 0 then math.min(spaces, indent) else spaces
		if consumed > maxIndent then
			maxIndent = consumed
		end
		if consumed == #raw then
			trailingBreaks ..= "\n"
			index += 1
		else
			position = consumed
			break
		end
	end
	if increment == 0 then
		indent = math.max(maxIndent, blockIndent + 1)
		if blockIndent > 0 then
			indent = math.max(indent, 1)
		end
	end

	if index > #lines then
		-- The end of the stream with no content, or the end of a document before a marker line
		state.pos = index
		if state.streamEnd then
			if chomp == "strip" or not hasBreak then
				return ""
			elseif chomp == "clip" then
				return "\n"
			end
			return if trailingBreaks == "" then "\n" else trailingBreaks
		end
		return if chomp == "keep" then trailingBreaks else ""
	end

	if position < indent and position > blockIndent then
		fail("wrongly indented line in block scalar")
	end

	local parts = {}
	local leadingBreak = ""
	local leadingBlank = false
	local endedWithoutBreak = false

	while index <= #lines and position == indent do
		local raw = lines[index].raw
		local content = raw:sub(indent + 1)
		local trailingBlank = isBlank(content:sub(1, 1))
		if not literal and leadingBreak ~= "" and not leadingBlank and not trailingBlank then
			table.insert(parts, trailingBreaks)
			if trailingBreaks == "" then
				table.insert(parts, " ")
			end
		else
			table.insert(parts, leadingBreak)
			table.insert(parts, trailingBreaks)
		end
		leadingBreak, trailingBreaks = "", ""
		leadingBlank = trailingBlank
		table.insert(parts, content)

		if index == #lines and not (#state.source >= lines[index].start + #raw) then
			endedWithoutBreak = true
			index += 1
			break
		end
		leadingBreak = "\n"
		index += 1

		-- The indentation of the next lines, and the blank lines among them
		position = 0
		while index <= #lines do
			local nextRaw = lines[index].raw
			local spaces = #(nextRaw:match("^( *)") :: string)
			local consumed = math.min(spaces, indent)
			if consumed == #nextRaw then
				trailingBreaks ..= "\n"
				index += 1
			else
				position = consumed
				break
			end
		end
	end

	if chomp ~= "strip" then
		table.insert(parts, leadingBreak)
		if endedWithoutBreak and state.streamEnd then
			table.insert(parts, "\n")
		end
	end
	if chomp == "keep" then
		table.insert(parts, trailingBreaks)
	end

	state.pos = index
	return table.concat(parts)
end

-- Wally-Plugin addition: the empty node yaml-rust2 reads where a node's properties have no content after them
local function emptyNode(state: ParseState, properties: Properties?): (any, string?)
	local id = beginNode(state, properties)
	local value, identity = resolveTagged(state, "", properties and properties.tag)
	return endNode(state, id, value, identity)
end

--- Parse a flow sequence: [a, b, c]
--- Returns (value, nextPos) where nextPos is the position after closing ].
-- Wally-Plugin change: comments, line breaks and every whitespace yaml-rust2 skips between flow tokens
local function skipFlowSpace(state: ParseState, offset: number): number
	local source = state.source
	local p = offset
	while p <= #source do
		local c = source:sub(p, p)
		if c == " " or c == "\t" or c == "\n" then
			p += 1
		elseif c == "#" then
			p = source:find("\n", p, true) or #source + 1
		else
			break
		end
	end
	return p
end

local function checkFlowComment(state: ParseState, offset: number)
	if state.source:sub(offset, offset) == "#" then
		fail("comments must be separated from other tokens by whitespace")
	end
end

-- yaml-rust2 refuses a flow token left of its block's indentation, which is one column past the block's own
-- inside a mapping value or a sequence entry until the first plain scalar in the flow drops it back
local function checkFlowIndent(state: ParseState, offset: number)
	if offset <= #state.source and columnAt(state, offset) < state.flowIndent then
		fail("invalid indentation")
	end
end

-- Wally-Plugin change: the entries of a flow sequence, where a `key: value` entry is a mapping of one pair,
-- with yaml-rust2's rules for commas
local function parseFlowSequence(state: ParseState, offset: number, blockIndent: number, properties: Properties?): (any, number)
	local source = state.source
	local array = newArray()
	local id = beginNode(state, properties)
	local p = offset + 1
	checkFlowComment(state, p)
	local first = true

	while true do
		p = skipFlowSpace(state, p)
		checkFlowIndent(state, p)
		local c = source:sub(p, p)
		if c == "" then
			fail("while parsing a flow sequence, expected ',' or ']'")
		end
		if c == "]" then
			p += 1
			break
		end
		if not first then
			if c ~= "," then
				fail("while parsing a flow sequence, expected ',' or ']'")
			end
			p += 1
			checkFlowComment(state, p)
			p = skipFlowSpace(state, p)
			checkFlowIndent(state, p)
			c = source:sub(p, p)
			if c == "]" then
				p += 1
				break
			end
		end
		first = false

		local entryLine = lineAt(state, p)
		local key, keyIdentity, kind
		local explicit = c == "?" and isBlankOrEnd(source:sub(p + 1, p + 1))
		if explicit then
			p = skipFlowSpace(state, p + 1)
			c = source:sub(p, p)
		end
		if c == ":" and (isBlankOrEnd(source:sub(p + 1, p + 1)) or isFlowIndicator(source:sub(p + 1, p + 1))) then
			key, keyIdentity, kind = newNull(), "Null", "empty"
		elseif explicit and (c == "," or c == "]") then
			key, keyIdentity, kind = newNull(), "Null", "empty"
		else
			key, keyIdentity, p, kind = parseFlow(state, p, blockIndent)
		end

		local q = skipFlowSpace(state, p)
		checkFlowIndent(state, q)
		local colon = source:sub(q, q) == ":"
			and (isBlankOrEnd(source:sub(q + 1, q + 1)) or isFlowIndicator(source:sub(q + 1, q + 1)) or (q == p and (kind == "quoted" or kind == "flow")) or (kind == "quoted" or kind == "flow"))
		if colon or explicit then
			if colon and not explicit and lineAt(state, q) ~= entryLine then
				fail("illegal placement of ':' indicator")
			end
			local value, valueIdentity = newNull(), "Null"
			if colon then
				q = skipFlowSpace(state, q + 1)
				local n = source:sub(q, q)
				if n ~= "," and n ~= "]" then
					value, valueIdentity, q = parseFlow(state, q, blockIndent)
				end
			end
			local pair: MapBuilder = { map = newMap() }
			pushMapNode(state, pair, key, keyIdentity)
			pushMapNode(state, pair, value, valueIdentity)
			key = pair.map
			p = q
		elseif kind == "empty" then
			fail("while parsing a node, did not find expected node content")
		end
		table.insert(array.items, key)
	end

	endNode(state, id, array, nil)
	return array, p
end

--- Parse a flow mapping: {a: 1, b: 2}
-- Wally-Plugin change: DataValue maps in written order, keys of any type, a key with no value mapping to null
-- (`{a, b}`), explicit `?` keys, and JSON-like `"a":1`
local function parseFlowMapping(state: ParseState, offset: number, blockIndent: number, properties: Properties?): (any, number)
	local source = state.source
	local builder: MapBuilder = { map = newMap() }
	local id = beginNode(state, properties)
	local p = offset + 1
	checkFlowComment(state, p)
	local first = true

	while true do
		p = skipFlowSpace(state, p)
		checkFlowIndent(state, p)
		local c = source:sub(p, p)
		if c == "" then
			fail("while parsing a flow mapping, did not find expected ',' or '}'")
		end
		if c == "}" then
			p += 1
			break
		end
		if not first then
			if c ~= "," then
				fail("while parsing a flow mapping, did not find expected ',' or '}'")
			end
			p += 1
			checkFlowComment(state, p)
			p = skipFlowSpace(state, p)
			checkFlowIndent(state, p)
			c = source:sub(p, p)
			if c == "}" then
				p += 1
				break
			end
		end
		first = false

		local key, keyIdentity, kind
		if c == "?" and isBlankOrEnd(source:sub(p + 1, p + 1)) then
			p = skipFlowSpace(state, p + 1)
			c = source:sub(p, p)
		end
		if c == ":" and (isBlankOrEnd(source:sub(p + 1, p + 1)) or isFlowIndicator(source:sub(p + 1, p + 1))) then
			key, keyIdentity, kind = newNull(), "Null", "empty"
		elseif c == "," or c == "}" then
			key, keyIdentity, kind = newNull(), "Null", "empty"
		else
			key, keyIdentity, p, kind = parseFlow(state, p, blockIndent)
		end

		local q = skipFlowSpace(state, p)
		checkFlowIndent(state, q)
		local value, valueIdentity = newNull(), "Null"
		local n = source:sub(q + 1, q + 1)
		if source:sub(q, q) == ":" and (isBlankOrEnd(n) or isFlowIndicator(n) or kind == "quoted" or kind == "flow") then
			q = skipFlowSpace(state, q + 1)
			local v = source:sub(q, q)
			if v ~= "," and v ~= "}" then
				value, valueIdentity, q = parseFlow(state, q, blockIndent)
			end
			p = q
		end
		pushMapNode(state, builder, key, keyIdentity)
		pushMapNode(state, builder, value, valueIdentity)
	end

	endNode(state, id, builder.map, nil)
	return builder.map, p
end

--- Parse a single flow value (scalar, flow sequence, or flow mapping).
-- Wally-Plugin change: also anchors, tags and aliases, on the document's text; returns the value, its key
-- identity, the offset after it and its kind (`scalar`, `quoted`, `flow`, `alias` or `empty`)
parseFlow = function(state: ParseState, offset: number, blockIndent: number, inherited: Properties?): (any, string?, number, string)
	local source = state.source
	local p = offset
	local properties: Properties = { anchor = inherited and inherited.anchor, tag = inherited and inherited.tag }

	while true do
		local c = source:sub(p, p)
		if c == "&" then
			if properties.anchor then
				fail("while parsing a node, did not find expected node content")
			end
			local nameEnd = scanAnchorName(source, p + 1)
			properties.anchor = source:sub(p + 1, nameEnd - 1)
			p = skipFlowSpace(state, nameEnd)
		elseif c == "!" then
			if properties.tag then
				fail("while parsing a node, did not find expected node content")
			end
			local tag, tagEnd = scanTag(state, source, p, true)
			properties.tag = tag
			p = skipFlowSpace(state, tagEnd)
		else
			break
		end
	end

	local c = source:sub(p, p)
	if c == "[" then
		local value, after = parseFlowSequence(state, p, blockIndent, properties)
		checkFlowComment(state, after)
		return value, nil, after, "flow"
	elseif c == "{" then
		local value, after = parseFlowMapping(state, p, blockIndent, properties)
		checkFlowComment(state, after)
		return value, nil, after, "flow"
	elseif c == '"' or c == "'" then
		local id = beginNode(state, properties)
		local text, after = tryQuoted(state, p, state.flowIndent, true)
		local value, identity = endNode(state, id, text, stringIdentity(text))
		return value, identity, after, "quoted"
	elseif c == "*" then
		if properties.anchor or properties.tag then
			fail("while parsing a node, did not find expected node content")
		end
		local nameEnd = scanAnchorName(source, p + 1)
		local value, identity = resolveAlias(state, source:sub(p + 1, nameEnd - 1))
		return value, identity, nameEnd, "alias"
	elseif
		c == ""
		or c == ","
		or c == "]"
		or c == "}"
		or (c == ":" and (isBlankOrEnd(source:sub(p + 1, p + 1)) or isFlowIndicator(source:sub(p + 1, p + 1))))
	then
		if properties.anchor or properties.tag then
			local value, identity = emptyNode(state, properties)
			return value, identity, p, "scalar"
		end
		return newNull(), "Null", p, "empty"
	elseif c == "%" or c == "@" or c == "`" then
		fail(`unexpected character: \`{c}'`)
	elseif c == "-" and isBlankOrEnd(source:sub(p + 1, p + 1)) then
		fail('"-" is only valid inside a block')
	end

	local id = beginNode(state, properties)
	if state.flowIndent > blockIndent then
		state.flowIndent = blockIndent
	end
	local text, after = readPlain(state, p, true, blockIndent + 1)
	local value, identity = resolveTagged(state, text, properties.tag)
	value, identity = endNode(state, id, value, identity)
	return value, identity, after, "scalar"
end

-- Wally-Plugin addition: whether a line holds an implicit key from `column`: properties, then a quoted scalar
-- closed on the line, an alias or a plain scalar, then `:` and a blank
local function isImplicitKey(state: ParseState, lineIndex: number, column: number): boolean
	local raw = state.lines[lineIndex].raw
	local p = column + 1
	local c = raw:sub(p, p)

	if c == '"' or c == "'" then
		local q = p + 1
		while q <= #raw do
			local d = raw:sub(q, q)
			if c == "'" and d == "'" then
				if raw:sub(q + 1, q + 1) == "'" then
					q += 2
					continue
				end
				break
			elseif c == '"' and d == "\\" then
				q += 2
				continue
			elseif c == '"' and d == '"' then
				break
			end
			q += 1
		end
		if q > #raw then
			return false
		end
		p = q + 1
	elseif c == "*" then
		p = scanAnchorName(raw, p + 1)
	elseif c == "[" or c == "{" then
		-- a flow collection closed on this line, its quoted scalars skipped
		local depth = 0
		local quote = nil
		while p <= #raw do
			local d = raw:sub(p, p)
			if quote == "'" then
				if d == "'" then
					if raw:sub(p + 1, p + 1) == "'" then
						p += 1
					else
						quote = nil
					end
				end
			elseif quote == '"' then
				if d == "\\" then
					p += 1
				elseif d == '"' then
					quote = nil
				end
			elseif d == "'" or d == '"' then
				quote = d
			elseif d == "[" or d == "{" then
				depth += 1
			elseif d == "]" or d == "}" then
				depth -= 1
				if depth == 0 then
					break
				end
			elseif d == "#" and isBlank(raw:sub(p - 1, p - 1)) then
				return false
			end
			p += 1
		end
		if p > #raw then
			return false
		end
		p += 1
	elseif c == "" or ("]}#|>%@`,"):find(c, 1, true) then
		return false
	else
		while p <= #raw do
			local d = raw:sub(p, p)
			if d == ":" and isBlankOrEnd(raw:sub(p + 1, p + 1)) then
				return true
			end
			if isBlank(d) and raw:sub(p + 1, p + 1) == "#" then
				return false
			end
			p += 1
		end
		return false
	end

	while isBlank(raw:sub(p, p)) do
		p += 1
	end
	return raw:sub(p, p) == ":" and isBlankOrEnd(raw:sub(p + 1, p + 1))
end

-- Wally-Plugin addition: reads the implicit key at `column` (with its properties) and returns it, its identity
-- and the column after its `:`
local function parseImplicitKey(state: ParseState, lineIndex: number, column: number): (any, string?, number)
	local line = state.lines[lineIndex]
	local raw = line.raw
	local properties, p = scanProperties(state, raw, column + 1, nil)
	if not isImplicitKey(state, lineIndex, p - 1) then
		fail("could not find expected ':'")
	end
	local c = raw:sub(p, p)
	local key, identity, after
	if c == "[" or c == "{" then
		local endOffset
		state.flowIndent = column
		key, identity, endOffset = parseFlow(state, line.start + column, column, nil)
		after = endOffset - line.start + 1
	elseif c == "*" then
		if properties.anchor or properties.tag then
			fail("while parsing a node, did not find expected node content")
		end
		local nameEnd = scanAnchorName(raw, p + 1)
		key, identity = resolveAlias(state, raw:sub(p + 1, nameEnd - 1))
		after = nameEnd
	else
		local id = beginNode(state, properties)
		if c == '"' or c == "'" then
			local text, endOffset = tryQuoted(state, line.start + p - 1, -1, false)
			key, identity = text, stringIdentity(text)
			after = endOffset - line.start + 1
		else
			local text, endOffset = readPlain(state, line.start + p - 1, false, 0)
			key, identity = resolveTagged(state, text, properties.tag)
			after = endOffset - line.start + 1
		end
		key, identity = endNode(state, id, key, identity)
	end
	while isBlank(raw:sub(after, after)) do
		after += 1
	end
	-- yaml-rust2 forgets a possible key 1024 characters after it starts
	if (utf8.len(raw:sub(column + 1, after - 1)) or 0) > 1024 then
		fail("mapping values are not allowed in this context")
	end
	-- `after` is the colon; yaml-rust2 refuses a tab after it that is not followed by a space when a word or
	-- a `-` comes next
	local q = after + 1
	if raw:sub(q, q) == "\t" then
		local sawSpace = false
		while isBlank(raw:sub(q, q)) do
			sawSpace = sawSpace or raw:sub(q, q) == " "
			q += 1
		end
		local n = raw:sub(q, q)
		if not sawSpace and (n == "-" or n:find("^[%w_]$")) then
			fail("':' must be followed by a valid YAML whitespace")
		end
	end
	return key, identity, after
end

local function isBlockEntry(line: Line, column: number): boolean
	return line.raw:sub(column + 1, column + 1) == "-" and isBlankOrEnd(line.raw:sub(column + 2, column + 2))
end

--- Parse a block sequence starting at the given indent.
-- Wally-Plugin change: DataValue arrays; each entry is any node, read by `parseNode`, so a compact mapping,
-- a nested sequence, a block scalar or a quoted key may follow the dash
local function parseBlockSequence(state: ParseState, lineIndex: number, seqIndent: number, properties: Properties?): any
	local arr = newArray()
	local id = beginNode(state, properties)
	local entryLine = lineIndex

	while true do
		-- yaml-rust2 refuses a tab between two dashes
		local afterDash = state.lines[entryLine].raw:sub(seqIndent + 2)
		local blanks = afterDash:match("^[ \t]*") :: string
		if blanks:find("\t") and afterDash:sub(#blanks + 1, #blanks + 1) == "-" and isBlankOrEnd(afterDash:sub(#blanks + 2, #blanks + 2)) then
			fail("'-' must be followed by a valid YAML whitespace")
		end
		local value = parseNode(state, entryLine, seqIndent + 1, seqIndent, "entry", nil)
		table.insert(arr.items, value)

		local nextIndex = skipBlanks(state, state.pos)
		if nextIndex == nil then
			state.pos = #state.lines + 1
			break
		end
		local nextLine = state.lines[nextIndex]
		if nextLine.indent < seqIndent then
			state.pos = nextIndex
			break
		end
		checkTabs(nextLine)
		if nextLine.indent > seqIndent then
			fail("while parsing a block collection, did not find expected '-' indicator")
		end
		if not isBlockEntry(nextLine, seqIndent) then
			state.pos = nextIndex
			break
		end
		entryLine = nextIndex
	end

	endNode(state, id, arr, nil)
	return arr
end

--- Parse a block mapping starting at the given indent.
-- Wally-Plugin change: DataValue maps in written order with keys of any type; explicit `?` keys; a sequence at
-- the mapping's own indentation as a value; a key the mapping already holds refused; content indented past a
-- complete entry refused
local function parseBlockMapping(state: ParseState, lineIndex: number, mapIndent: number, properties: Properties?): any
	local builder: MapBuilder = { map = newMap() }
	local id = beginNode(state, properties)
	local entryLine = lineIndex
	local lines = state.lines

	while true do
		local raw = lines[entryLine].raw
		local c = raw:sub(mapIndent + 1, mapIndent + 1)
		local key, keyIdentity, value, valueIdentity
		if c == "?" and isBlankOrEnd(raw:sub(mapIndent + 2, mapIndent + 2)) then
			key, keyIdentity = parseNode(state, entryLine, mapIndent + 1, mapIndent, "key", nil)
			local valueIndex = skipBlanks(state, state.pos)
			local valueLine = valueIndex and lines[valueIndex]
			if
				valueLine
				and valueLine.indent == mapIndent
				and valueLine.raw:sub(mapIndent + 1, mapIndent + 1) == ":"
				and isBlankOrEnd(valueLine.raw:sub(mapIndent + 2, mapIndent + 2))
			then
				value, valueIdentity = parseNode(state, valueIndex :: number, mapIndent + 1, mapIndent, "explicit", nil)
			else
				value, valueIdentity = newNull(), "Null"
			end
		elseif c == ":" and isBlankOrEnd(raw:sub(mapIndent + 2, mapIndent + 2)) then
			key, keyIdentity = newNull(), "Null"
			value, valueIdentity = parseNode(state, entryLine, mapIndent + 1, mapIndent, "explicit", nil)
		else
			local colonColumn
			key, keyIdentity, colonColumn = parseImplicitKey(state, entryLine, mapIndent)
			value, valueIdentity = parseNode(state, entryLine, colonColumn, mapIndent, "value", nil)
		end
		pushMapNode(state, builder, key, keyIdentity)
		pushMapNode(state, builder, value, valueIdentity)

		local nextIndex = skipBlanks(state, state.pos)
		if nextIndex == nil then
			state.pos = #lines + 1
			break
		end
		local nextLine = lines[nextIndex]
		if nextLine.indent < mapIndent then
			state.pos = nextIndex
			break
		end
		checkTabs(nextLine)
		if nextLine.indent > mapIndent then
			fail("while parsing a block mapping, did not find expected key")
		end
		entryLine = nextIndex
	end

	endNode(state, id, builder.map, nil)
	return builder.map
end

--- Main node parser: determines if the current position starts a sequence,
--- mapping, or scalar, and dispatches accordingly.
-- Wally-Plugin change: reads the node whose content starts at or after `column` on line `lineIndex`, inside a
-- block collection at `blockIndent` (-1 at the document's root). `context` is where the node sits: `value`
-- (after an implicit key's `:`), `entry` (after `-`), `key` (after `?`), `explicit` (after the `:` of a `?` key
-- or of an empty key), `next` (on the line after a node's properties or indicator), `document`
-- (at the start of a document) or `marker` (after `---`). Properties read on an earlier line arrive as
-- `inherited`. Returns the value and its key identity, and leaves `state.pos` at the first line not read.
parseNode = function(state: ParseState, lineIndex: number, column: number, blockIndent: number, context: string, inherited: Properties?): (any, string?)
	local line = state.lines[lineIndex]
	local raw = line.raw
	local position = column + 1
	local spaced = position == 1 or isBlank(raw:sub(position - 1, position - 1))
	while isBlank(raw:sub(position, position)) do
		position += 1
		spaced = true
	end

	local properties, afterProperties = scanProperties(state, raw, position, inherited)
	if afterProperties > position then
		spaced = isBlank(raw:sub(afterProperties - 1, afterProperties - 1))
	end
	position = afterProperties
	local c = raw:sub(position, position)
	local allowKeys = context ~= "value" and context ~= "marker"
	local quotedIndent = if context == "value" or context == "explicit" then blockIndent + 1 else blockIndent

	-- Nothing more on this line: the node starts on a later one, or is empty
	if c == "" or c == "#" then
		if c == "#" and not spaced then
			fail("comments must be separated from other tokens by whitespace")
		end
		local merged = mergeProperties(inherited, properties)
		local nextIndex = skipBlanks(state, lineIndex + 1)
		if nextIndex then
			local nextLine = state.lines[nextIndex]
			if nextLine.indent > blockIndent then
				checkTabs(nextLine)
				local value, identity = parseNode(state, nextIndex, nextLine.indent, blockIndent, "next", merged)
				return value, identity
			elseif nextLine.indent == blockIndent and (context == "value" or context == "key" or context == "explicit") and isBlockEntry(nextLine, blockIndent) then
				return parseBlockSequence(state, nextIndex, blockIndent, merged), nil
			end
		end
		state.pos = nextIndex or #state.lines + 1
		return emptyNode(state, merged)
	end

	if context == "next" then
		allowKeys = true
		quotedIndent = blockIndent + 1
	end

	local contentColumn = position - 1
	local blockEntry = c == "-" and isBlankOrEnd(raw:sub(position + 1, position + 1))
	local explicitKey = c == "?" and isBlankOrEnd(raw:sub(position + 1, position + 1))

	if blockEntry or explicitKey then
		if not allowKeys or properties.anchor or properties.tag then
			fail(if blockEntry
				then "block sequence entries are not allowed in this context"
				else "mapping keys are not allowed in this context")
		end
		if blockEntry then
			return parseBlockSequence(state, lineIndex, contentColumn, inherited), nil
		end
		return parseBlockMapping(state, lineIndex, contentColumn, inherited), nil
	end

	if isImplicitKey(state, lineIndex, contentColumn) then
		if not allowKeys then
			fail("mapping values are not allowed in this context")
		end
		return parseBlockMapping(state, lineIndex, properties.column or contentColumn, inherited), nil
	end

	local merged = mergeProperties(inherited, properties)
	local offset = line.start + contentColumn

	if c == "|" or c == ">" then
		local id = beginNode(state, merged)
		local text = parseBlockScalar(state, lineIndex, contentColumn, blockIndent)
		return endNode(state, id, text, stringIdentity(text))
	elseif c == "[" or c == "{" then
		state.flowIndent = if context == "key" or blockIndent < 0 then blockIndent else blockIndent + 1
		local value, _, after = parseFlow(state, offset, blockIndent, merged)
		finishLine(state, after)
		return value, nil
	elseif c == '"' or c == "'" then
		local id = beginNode(state, merged)
		local text, after = tryQuoted(state, offset, quotedIndent, false)
		finishLine(state, after)
		return endNode(state, id, text, stringIdentity(text))
	elseif c == "*" then
		if merged.anchor or merged.tag then
			fail("while parsing a node, did not find expected node content")
		end
		local nameEnd = scanAnchorName(raw, position + 1)
		local value, identity = resolveAlias(state, raw:sub(position + 1, nameEnd - 1))
		finishLine(state, line.start + nameEnd - 1)
		return value, identity
	elseif c == "%" or c == "@" or c == "`" then
		fail(`unexpected character: \`{c}'`)
	elseif c == "," or c == "]" or c == "}" then
		fail("while parsing a node, did not find expected node content")
	end

	local id = beginNode(state, merged)
	local text, after, atIndicator = readPlain(state, offset, false, blockIndent + 1)
	local source = state.source
	if atIndicator then
		fail("mapping values are not allowed in this context")
	end
	if source:sub(after, after) == "#" then
		state.pos = lineAt(state, after) + 1
	else
		state.pos = lineAt(state, after)
	end
	local value, identity = resolveTagged(state, text, merged.tag)
	return endNode(state, id, value, identity)
end

-- Wally-Plugin addition: one document's lines, from the line it starts on (`---` lines start at column 3)
local function parseDocument(state: ParseState, lines: { Line }, source: string, startColumn: number, streamEnd: boolean): any
	state.lines = lines
	state.source = source
	state.streamEnd = streamEnd
	state.pos = 1
	state.anchors = {}

	local first = skipBlanks(state, 1)
	local value
	if startColumn > 0 then
		value = parseNode(state, 1, startColumn, -1, "marker", nil)
	elseif first then
		value = parseNode(state, first, 0, -1, "document", nil)
	else
		return newNull()
	end

	if skipBlanks(state, state.pos) then
		fail("did not find expected <document start>")
	end
	return finishValue(state, value)
end

-- Wally-Plugin addition: a line at column 0 that is `---` or `...` followed by a blank or the line's end
local function markerOf(raw: string): string?
	local marker = raw:sub(1, 3)
	if (marker == "---" or marker == "...") and isBlankOrEnd(raw:sub(4, 4)) then
		return marker
	end
	return nil
end

-- Wally-Plugin addition: a `%YAML` or `%TAG` directive line; returns the handle and prefix of a `%TAG`
local function parseDirective(raw: string): (string?, string?, string?)
	local name, rest = raw:match("^%%([%w_%-]*)(.*)$")
	if name == "" or name == nil then
		fail("while scanning a directive, could not find expected directive name")
	end
	if not isBlankOrEnd((rest :: string):sub(1, 1)) then
		fail("while scanning a directive, found unexpected non-alphabetical character")
	end
	local body = (rest :: string):gsub("^[ \t]+", "")
	local remainder
	if name == "YAML" then
		local major, minor, after = body:match("^(%d+)%.(%d+)(.*)$")
		if major == nil or #major > 9 or #minor > 9 then
			fail("while scanning a YAML directive, did not find expected version number")
		end
		remainder = after
	elseif name == "TAG" then
		local handle, afterHandle = body:match("^(![%w_%-]*!?)(.*)$")
		if handle == nil or (handle ~= "!" and handle:sub(-1) ~= "!") then
			fail("while parsing a tag directive, did not find expected '!'")
		end
		local prefixText = (afterHandle :: string):gsub("^[ \t]+", "")
		local prefix, afterPrefix = prefixText:match("^([^ \t]+)(.*)$")
		if prefix == nil then
			fail("invalid global tag character")
		end
		local decoded = {}
		local p = 1
		while p <= #prefix do
			local character = prefix:sub(p, p)
			if character == "%" then
				local text
				text, p = scanUriEscapes(prefix, p)
				table.insert(decoded, text)
			elseif isUriChar(character) then
				table.insert(decoded, character)
				p += 1
			else
				fail("while scanning TAG, did not find expected whitespace or line break")
			end
		end
		remainder = afterPrefix
		local trimmed = (remainder :: string):gsub("^[ \t]+", "")
		if trimmed ~= "" and not (trimmed:sub(1, 1) == "#" and trimmed ~= remainder) then
			fail("while scanning a directive, did not find expected comment or line break")
		end
		return name, handle, table.concat(decoded)
	else
		return name
	end
	local trimmed = (remainder :: string):gsub("^[ \t]+", "")
	if trimmed ~= "" and not (trimmed:sub(1, 1) == "#" and trimmed ~= remainder) then
		fail("while scanning a directive, did not find expected comment or line break")
	end
	return name
end

--[=[
	Wally-Plugin addition: decodes every document of a YAML stream, as yaml-rust2's `YamlLoader::load_from_str`
	reads them.

	Throws on text yaml-rust2 refuses. Returns the documents as DataValues (empty when the stream holds none) and
	the message for the first value Rojo 7.7.1's YAML-to-Luau conversion refuses, if any: an integer above 2^53,
	or a value yaml-rust2 reads as `BadValue` (an alias inside its own anchor's node, a tagged scalar its tag
	cannot hold).

	@param str string -- A YAML stream.
	@return { any } -- The documents.
	@return string? -- The first conversion problem.
]=]
function yaml.decodeDocuments(str: string): ({ any }, string?)
	-- yaml-rust2 reads a NUL character as the end of the stream
	local nul = str:find("\0", 1, true)
	local text = (if nul then str:sub(1, nul - 1) else str):gsub("\r\n", "\n"):gsub("\r", "\n")
	local all = splitLines(text)
	local state: ParseState = {
		lines = {},
		pos = 1,
		anchors = {},
		source = "",
		values = {},
		anchorCount = 0,
		tags = {},
		streamEnd = true,
		keys = setmetatable({}, { __mode = "k" }) :: any,
		problem = nil,
		flowIndent = -1,
	}
	local documents = {}

	-- Splits the stream into documents as yaml-rust2's parser does: `---` starts one, `...` ends one, content
	-- with neither starts one at the beginning of the stream or after `...`, and directives come before `---`
	local open: { first: number, column: number }? = nil
	local version = false
	local pendingDirectives = false
	local tags: { [string]: string } = {}

	local function close(last: number)
		if open == nil then
			return
		end
		local first = open.first
		local lines = {}
		local base = all[first].start
		for index = first, last do
			local line = all[index]
			table.insert(lines, { indent = line.indent, text = line.text, raw = line.raw, start = line.start - base + 1 })
		end
		local finish = if last < #all then all[last + 1].start - 1 else #text
		local source = text:sub(base, finish)
		state.tags = tags
		table.insert(documents, parseDocument(state, lines, source, open.column, last == #all))
		open = nil
		tags = {}
		version = false
	end

	for index, line in all do
		local marker = markerOf(line.raw)
		if marker == "---" then
			close(index - 1)
			open = { first = index, column = 3 }
			pendingDirectives = false
		elseif marker == "..." then
			local rest = line.raw:sub(4)
			local trimmed = rest:gsub("^[ \t]+", "")
			if trimmed ~= "" and not (trimmed:sub(1, 1) == "#" and trimmed ~= rest) then
				fail("invalid content after document end marker")
			end
			close(index - 1)
			if pendingDirectives then
				fail("did not find expected <document start>")
			end
		elseif line.raw:sub(1, 1) == "%" and open == nil then
			local name, handle, prefix = parseDirective(line.raw)
			if name == "YAML" then
				if version then
					fail("duplicate version directive")
				end
				version = true
				tags = {}
			elseif handle then
				tags = { [handle] = prefix :: string }
			else
				tags = { [""] = "" }
			end
			pendingDirectives = true
		elseif open == nil and not isBlankOrCommentLine(line) then
			if pendingDirectives then
				fail("did not find expected <document start>")
			end
			open = { first = index, column = 0 }
		end
	end
	close(#all)
	if pendingDirectives then
		fail("did not find expected <document start>")
	end

	return documents, state.problem
end

--[=[
	Decodes a YAML string into a Luau value.

	Supports block and flow scalars/sequences/mappings, multi-line strings
	(literal `|` and folded `>`), anchors/aliases, and YAML 1.2 core schema
	type resolution.

	Only the first document is parsed when `---` separators are present.

	```luau
	local yaml = require("@eryx/data/yaml")
	local config = yaml.decode([[
	name: My App
	version: 1.2
	features:
	  - auth
	  - logging
	]])
	print(config.name)  -- "My App"
	```

	@param str string -- A valid YAML string.
	@return any -- The decoded Luau value.
]=]
-- Wally-Plugin change: the first document of `yaml.decodeDocuments`, as a DataValue
function yaml.decode(str: string): any
	local documents = yaml.decodeDocuments(str)
	return documents[1]
end

return yaml
