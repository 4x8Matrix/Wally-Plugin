local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local yaml = require(script.Parent.Parent.Vendor.eryx.yaml)

local Finders = {}

--[[
	Says whether `value` holds a mapping with a null key, or is a null key itself when `isKey` is set.
]]
local function findNullKey(value: Types.DataValue, isKey: boolean): boolean
	local find = Finders[typeof(value)]

	return if find then find(value, isKey) else false
end

function Finders.table(value: Types.DataNull | Types.DataArray | Types.DataMap, isKey: boolean): boolean
	if value.kind == "null" then
		return isKey
	end

	if value.kind == "array" then
		for _, item in value.items do
			if findNullKey(item, false) then
				return true
			end
		end

		return false
	end

	for _, entry in value.entries do
		if findNullKey(entry.key, true) or findNullKey(entry.value, false) then
			return true
		end
	end

	return false
end

-- seam: a root block scalar from column 0 ends at `---`, yaml-rust2's at `...`; upgrade trigger: a package doing it
--[[
	Decodes `text` as Rojo 7.7.1 reads a `.yaml` or `.yml` file, through yaml-rust2 0.10.4: exactly one
		document, mappings in written order with keys of any type, aliases copied from their anchored nodes, and
		scalars resolved as yaml-rust2 resolves them. Rojo's refusals come in its order: text yaml-rust2 refuses,
		then no document or several, then the first value Rojo cannot convert (an integer above 2^53, or one
		yaml-rust2 reads as a bad value). A null mapping key is refused last, where Rojo crashes. The vendored
		eryx parser carries the changes that make it read YAML as yaml-rust2 does, listed in its NOTICE. Refusals
		use yaml-rust2's and Rojo's words without a position. The error names no path; the caller adds the file
		it read.
]]
return function(text: string): Types.BuildResult<Types.DataValue>
	if not utf8.len(text) then
		return buildError("", "File was not valid UTF-8")
	end

	local decoded, documents, problem = pcall(yaml.decodeDocuments, text)

	if not decoded then
		return buildError("", documents)
	end

	if #documents == 0 then
		return buildError("", "all YAML documents must contain a document")
	end

	if #documents > 1 then
		return buildError("", "Rojo does not currently support multiple documents in a YAML file")
	end

	if problem then
		return buildError("", problem)
	end

	if findNullKey(documents[1], false) then
		return buildError("", "Rojo cannot build a mapping with a null key (it crashes: nil cannot be a table key)")
	end

	return { ok = true, value = documents[1] }
end
