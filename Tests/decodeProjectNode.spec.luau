local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)
local decodeProjectNode = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeProjectNode)

local EMPTY = { kind = "map", entries = {} }
local UNRESOLVED = "data did not match any variant of untagged enum UnresolvedValue"
local PATH_NODE = "data did not match any variant of untagged enum PathNode"

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function decode(text: string): any
	return decodeProjectNode(decodeJsonc(text).value)
end

local function refusal(text: string): string
	local result = decode(text)

	expect(result.ok).toBe(false)

	return result.error.message
end

describe("decodeProjectNode", function()
	it("reads every node field and leaves the property and attribute values decoded", function()
		expect(decode([[{
			"$className": "StringValue",
			"$id": "main",
			"$path": "src",
			"$properties": {"Value": "v"},
			"$attributes": {"A": true},
			"$ignoreUnknownInstances": false
		}]])).toEqual({
			ok = true,
			value = {
				className = "StringValue",
				id = "main",
				path = { path = "src", optional = false },
				properties = { kind = "map", entries = { { key = "Value", value = "v" } } },
				attributes = { kind = "map", entries = { { key = "A", value = true } } },
				children = {},
			},
		})
	end)

	it("reads null as absent for $className, $id, $path and $ignoreUnknownInstances", function()
		expect(decode('{"$className": null, "$id": null, "$path": null, "$ignoreUnknownInstances": null}')).toEqual({
			ok = true,
			value = { properties = EMPTY, attributes = EMPTY, children = {} },
		})
	end)

	it("reads every other key as a child node, in key order, `$` keys included", function()
		local node = decode('{"b": {"$className": "Folder"}, "$x": {}, "a": {"c": {}}}').value

		expect(node.children).toEqual({
			{ name = "$x", node = { properties = EMPTY, attributes = EMPTY, children = {} } },
			{
				name = "a",
				node = {
					properties = EMPTY,
					attributes = EMPTY,
					children = { { name = "c", node = { properties = EMPTY, attributes = EMPTY, children = {} } } },
				},
			},
			{ name = "b", node = { className = "Folder", properties = EMPTY, attributes = EMPTY, children = {} } },
		})
	end)

	it("reads $path as a string, or as an object or array holding `optional`, whose other keys are ignored", function()
		expect(decode('{"$path": {"optional": "a.lua", "extra": 1}}').value.path).toEqual({
			path = "a.lua",
			optional = true,
		})
		expect(decode('{"$path": ["a.lua"]}').value.path).toEqual({ path = "a.lua", optional = true })
	end)

	it("refuses a $path of any other shape", function()
		expect(refusal('{"$path": 1}')).toBe(PATH_NODE)
		expect(refusal('{"$path": {}}')).toBe(PATH_NODE)
		expect(refusal('{"$path": {"optional": 1}}')).toBe(PATH_NODE)
		expect(refusal('{"$path": {"optional": null}}')).toBe(PATH_NODE)
		expect(refusal('{"$path": []}')).toBe(PATH_NODE)
	end)

	it("refuses a node or child that is not an object", function()
		expect(refusal("[]")).toBe("invalid type: sequence, expected struct ProjectNode")
		expect(refusal('{"k": null}')).toBe("invalid type: null, expected struct ProjectNode")
		expect(refusal('{"k": []}')).toBe("invalid type: sequence, expected struct ProjectNode")
		expect(refusal('{"$description": "hi"}')).toBe('invalid type: string "hi", expected struct ProjectNode')
		expect(refusal('{"a": {"b": {"c": 1}}}')).toBe("invalid type: integer `1`, expected struct ProjectNode")
	end)

	it("refuses a node field of the wrong type, and null for $properties and $attributes", function()
		expect(refusal('{"$className": 1}')).toBe("invalid type: integer `1`, expected a string")
		expect(refusal('{"$id": 1}')).toBe("invalid type: integer `1`, expected a string")
		expect(refusal('{"$ignoreUnknownInstances": "x"}')).toBe('invalid type: string "x", expected a boolean')
		expect(refusal('{"$properties": null}')).toBe("invalid type: null, expected a map")
		expect(refusal('{"$properties": []}')).toBe("invalid type: sequence, expected a map")
		expect(refusal('{"$attributes": null}')).toBe("invalid type: null, expected a map")
		expect(refusal('{"$attributes": []}')).toBe("invalid type: sequence, expected a map")
	end)

	it("refuses a property or attribute value no form of UnresolvedValue reads, wherever the node is", function()
		expect(refusal('{"$properties": {"Value": null}}')).toBe(UNRESOLVED)
		expect(refusal('{"$attributes": {"A": [[1]]}}')).toBe(UNRESOLVED)
		expect(refusal('{"gone": {"$path": {"optional": "nope"}, "kid": {"$properties": {"Value": null}}}}')).toBe(
			UNRESOLVED
		)
	end)
end)
