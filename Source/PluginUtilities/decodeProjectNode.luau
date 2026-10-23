local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local expectKind = require(script.Parent.expectKind)
local kindOfDataValue = require(script.Parent.kindOfDataValue)
local parseDataValue = require(script.Parent.parseDataValue)
local readStruct = require(script.Parent.readStruct)

local OPTIONAL_PATH = {
	name = "OptionalPathNode",
	fields = { { name = "optional", presence = "required" } },
	denyUnknownFields = false,
}
local PATH_NODE = "data did not match any variant of untagged enum PathNode"
local NODE_FIELDS = {
	["$className"] = "className",
	["$id"] = "id",
	["$path"] = "path",
	["$properties"] = "properties",
	["$attributes"] = "attributes",
	["$ignoreUnknownInstances"] = "ignoreUnknownInstances",
}
local EXPECTED = {
	["$className"] = { kind = "string", expected = "a string" },
	["$id"] = { kind = "string", expected = "a string" },
	["$ignoreUnknownInstances"] = { kind = "boolean", expected = "a boolean" },
	["$properties"] = { kind = "map", expected = "a map" },
	["$attributes"] = { kind = "map", expected = "a map" },
}

--[[
	Reads `$path` as Rojo's untagged PathNode: a string is required, an object or array holding a string `optional`
		is optional, and anything else matches neither variant.
]]
local function readPath(value: Types.DataValue): Types.BuildResult<Types.ProjectPath>
	if kindOfDataValue(value) == "string" then
		return { ok = true, value = { path = value, optional = false } }
	end

	local fields = readStruct(value, OPTIONAL_PATH)
	local optional = if fields.ok then fields.value.optional else nil

	if kindOfDataValue(optional) ~= "string" then
		return buildError("", PATH_NODE)
	end

	return { ok = true, value = { path = optional, optional = true } }
end

--[[
	Checks that every value of `$properties` or `$attributes` reads as an UnresolvedValue, as serde does when Rojo
		loads the file, before any node is built.
]]
local function checkValues(map: Types.DataMap): Types.BuildResult<Types.DataMap>
	for _, entry in map.entries do
		local parsed = parseDataValue(entry.value)

		if not parsed.ok then
			return parsed
		end
	end

	return { ok = true, value = map }
end

--[[
	Reads one of the node's own `$` fields: null as absent where the field is optional, the wrong kind refused in
		serde's words, `$path` as a PathNode and property and attribute maps checked value by value.
]]
local function readField(key: string, value: Types.DataValue): Types.BuildResult<any>
	local kind = kindOfDataValue(value)
	local expected = EXPECTED[key]

	if kind == "null" and key ~= "$properties" and key ~= "$attributes" then
		return { ok = true }
	end

	if key == "$path" then
		return readPath(value)
	end

	local checked = expectKind(value, expected.kind, expected.expected)

	if not checked.ok then
		return checked
	end

	return if kind == "map" then checkValues(value) else checked
end

--[[
	Decodes a project node as Rojo 7.7.1's ProjectNode (R2.2), which serde reads only from an object because its
		children are flattened into it: `$className`, `$id`, `$path`, `$properties`, `$attributes` and
		`$ignoreUnknownInstances` are its own fields, and every other key, `$`-prefixed ones included, is a child
		node, in key order. Property and attribute values stay decoded, each checked to read as an UnresolvedValue.
		A wrong field anywhere in the tree fails in serde's words; the error names no path.
]]
local function decodeProjectNode(value: Types.DataValue): Types.BuildResult<Types.ProjectNode>
	local node = {
		properties = { kind = "map", entries = {} },
		attributes = { kind = "map", entries = {} },
		children = {},
	}
	local checked = expectKind(value, "map", "struct ProjectNode")

	if not checked.ok then
		return checked
	end

	for _, entry in value.entries do
		local field = NODE_FIELDS[entry.key]
		local read = if field then readField(entry.key, entry.value) else decodeProjectNode(entry.value)

		if not read.ok then
			return read
		end

		if field and field ~= "ignoreUnknownInstances" then
			node[field] = read.value
		elseif not field then
			table.insert(node.children, { name = entry.key, node = read.value })
		end
	end

	return { ok = true, value = node }
end

return decodeProjectNode
