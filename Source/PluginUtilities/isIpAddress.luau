--[[
	Reads a number of at most `maxDigits` digits in `radix` at the cursor, as Rust's address parser does: more digits
		than that, a value past `limit`, or with `noZeroPrefix` a leading zero followed by more digits, read nothing.
		The cursor only moves on success.
]]
local function readNumber(
	reader: Reader,
	radix: number,
	maxDigits: number,
	limit: number,
	noZeroPrefix: boolean
): boolean
	local digits = string.match(reader.text, if radix == 16 then "^%x+" else "^%d+", reader.cursor) or ""
	local value = tonumber(digits, radix)

	if digits == "" or #digits > maxDigits or value > limit then
		return false
	end

	if noZeroPrefix and #digits > 1 and string.sub(digits, 1, 1) == "0" then
		return false
	end

	reader.cursor += #digits

	return true
end

--[[
	Reads a separator unless `index` is the first, then runs `read`, moving the cursor back when either fails.
]]
local function readSeparated(reader: Reader, separator: string, index: number, read: () -> boolean): boolean
	local start = reader.cursor

	if index > 0 and string.sub(reader.text, reader.cursor, reader.cursor) ~= separator then
		return false
	end

	if index > 0 then
		reader.cursor += 1
	end

	if not read() then
		reader.cursor = start

		return false
	end

	return true
end

local function readIpv4(reader: Reader): boolean
	local start = reader.cursor

	for index = 0, 3 do
		if not readSeparated(reader, ".", index, function()
			return readNumber(reader, 10, 3, 255, true)
		end) then
			reader.cursor = start

			return false
		end
	end

	return true
end

--[[
	Reads up to `limit` colon-separated groups, an IPv4 address standing for the last two when at least two are
		left, as Rust's `read_groups` does. Returns how many groups it read and whether it ended on an IPv4 address.
]]
local function readGroups(reader: Reader, limit: number): (number, boolean)
	for index = 0, limit - 1 do
		local tail = if index < limit - 1
			then readSeparated(reader, ":", index, function()
				return readIpv4(reader)
			end)
			else false

		if tail then
			return index + 2, true
		end

		if
			not readSeparated(reader, ":", index, function()
				return readNumber(reader, 16, 4, 0xFFFF, false)
			end)
		then
			return index, false
		end
	end

	return limit, false
end

local function readIpv6(reader: Reader): boolean
	local headSize, headIpv4 = readGroups(reader, 8)

	if headSize == 8 then
		return true
	end

	if headIpv4 or string.sub(reader.text, reader.cursor, reader.cursor + 1) ~= "::" then
		return false
	end

	reader.cursor += 2
	readGroups(reader, 8 - (headSize + 1))

	return true
end

type Reader = { text: string, cursor: number }

--[[
	Whether `text` is an IP address as Rust's `IpAddr::from_str` reads one, which Rojo 7.7.1 requires of
		`serveAddress`: four decimal octets without leading zeros, or eight hexadecimal groups, a `::` standing for
		one or more of them and an IPv4 address for the last two. Nothing else may surround it.
]]
return function(text: string): boolean
	for _, read in { readIpv4, readIpv6 } do
		local reader = { text = text, cursor = 1 }

		if read(reader) and reader.cursor == #text + 1 then
			return true
		end
	end

	return false
end
