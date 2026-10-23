local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local csv = require(script.Parent.Parent.Vendor.eryx.csv)

local INVALID_CSV = "File was not a valid LocalizationTable CSV file: "
local ENTRY_FIELDS = { Key = "key", Source = "source", Context = "context", Example = "example" }
local FIELD_ORDER = { "key", "context", "example", "source" }
local JSON_ESCAPES = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

--[[
	Writes `value` as a JSON string the way serde_json writes one: quotes, backslashes and control characters
		escaped, short forms where JSON has them, and everything else as it is.
]]
local function encodeString(value: string): string
	local escaped = string.gsub(value, '[%z\1-\31"\\]', function(character: string): string
		return JSON_ESCAPES[character] or string.format("\\u%04x", string.byte(character))
	end)

	return `"{escaped}"`
end

--[[
	Writes one localization entry as Rojo's `LocalizationEntry` serializes: `key`, `context`, `example` and
		`source` when present, then `values` with its locales sorted by bytes.
]]
local function encodeEntry(entry: { [string]: any }): string
	local parts = {}
	local locales = {}
	local values = {}

	for _, field in FIELD_ORDER do
		if entry[field] then
			table.insert(parts, `"{field}":{encodeString(entry[field])}`)
		end
	end

	for locale in entry.values do
		table.insert(locales, locale)
	end

	table.sort(locales)

	for _, locale in locales do
		table.insert(values, `{encodeString(locale)}:{encodeString(entry.values[locale])}`)
	end

	table.insert(parts, `"values":\{{table.concat(values, ",")}}`)

	return `\{{table.concat(parts, ",")}}`
end

--[[
	Builds the `Contents` of the `LocalizationTable` Rojo 7.7.1 makes from a `.csv` file. Records are read as the
		csv 1.4.0 crate reads them (a leading byte order mark stripped, CRLF, LF and CR ending records, empty lines
		skipped, quoted fields holding newlines); the first is the header row and every other must be as long.
		Each record pairs its fields with the headers, skipping an empty header or field: `Key`, `Source`,
		`Context` and `Example` fill those fields, any other header names a locale, and a repeated header
		overwrites the one before it. A record with neither a key nor a source is dropped. The result is the
		compact JSON array serde_json writes, `[]` when no record is kept. The error names no path; the caller
		adds the file it read.
]]
return function(text: string): Types.BuildResult<string>
	if not utf8.len(text) then
		return buildError("", `{INVALID_CSV}invalid UTF-8`)
	end

	local records = csv.parse(text, { skipblanklines = true })
	local headers = table.remove(records, 1) or {}
	local entries = {}

	for index, record in records do
		if #record ~= #headers then
			return buildError(
				"",
				`{INVALID_CSV}CSV error: record {index}: found record with {#record} fields, `
					.. `but the previous record has {#headers} fields`
			)
		end

		local entry = { values = {} }

		for column, header in headers do
			local value = record[column]
			local field = ENTRY_FIELDS[header]

			if header == "" or value == "" then
				continue
			end

			if field then
				entry[field] = value
			else
				entry.values[header] = value
			end
		end

		if entry.key or entry.source then
			table.insert(entries, encodeEntry(entry))
		end
	end

	return { ok = true, value = `[{table.concat(entries, ",")}]` }
end
