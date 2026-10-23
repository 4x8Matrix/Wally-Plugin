local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)
local decodeMetaFile = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeMetaFile)

local ADJACENT_REFUSALS = {
	{ "an empty array", "[]", "invalid length 0, expected struct AdjacentMetadata with 5 elements" },
	{ "an array of one", "[null]", "invalid length 1, expected struct AdjacentMetadata with 5 elements" },
	{ "an array of six", "[null, null, null, {}, {}, 1]", "invalid length 6, expected fewer elements in array" },
	{ "a number", "5", "invalid type: integer `5`, expected struct AdjacentMetadata" },
	{ "a string", '"s"', 'invalid type: string "s", expected struct AdjacentMetadata' },
	{ "null", "null", "invalid type: null, expected struct AdjacentMetadata" },
	{ "a boolean", "true", "invalid type: boolean `true`, expected struct AdjacentMetadata" },
	{ "a number for id", '{"id": 5}', "invalid type: integer `5`, expected a string" },
	{ "a number for $schema", '{"$schema": 1}', "invalid type: integer `1`, expected a string" },
	{
		"a string for ignoreUnknownInstances",
		'{"ignoreUnknownInstances": "yes"}',
		'invalid type: string "yes", expected a boolean',
	},
	{ "null properties", '{"properties": null}', "invalid type: null, expected a map" },
	{ "an array of properties", '{"properties": []}', "invalid type: sequence, expected a map" },
	{ "a number for properties", '{"properties": 1}', "invalid type: integer `1`, expected a map" },
	{ "null attributes", '{"attributes": null}', "invalid type: null, expected a map" },
	{ "an array of attributes", '{"attributes": []}', "invalid type: sequence, expected a map" },
	{ "a file holding only a comment", "// x", "File contains no JSON value" },
	{ "an empty file", "", "File contains no JSON value" },
	{ "invalid UTF-8", "a\255", "File is not valid UTF-8" },
}
local DIRECTORY_REFUSALS = {
	{ "a number for className", '{"className": 5}', "invalid type: integer `5`, expected a &str" },
	{
		"an array of seven",
		'[null, null, null, {}, {}, "Model", 1]',
		"invalid length 7, expected fewer elements in array",
	},
	{
		"an array of five",
		"[null, null, null, {}, {}]",
		"invalid length 5, expected struct DirectoryMetadata with 6 elements",
	},
	{
		"an array of three, whose defaulted fields serde passes",
		"[null, null, null]",
		"invalid length 5, expected struct DirectoryMetadata with 6 elements",
	},
	{ "a number", "5", "invalid type: integer `5`, expected struct DirectoryMetadata" },
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function map(text: string): any
	return decodeJsonc(text).value
end

local function meta(fields: { [string]: any }): any
	return {
		ok = true,
		value = {
			schema = fields.schema,
			id = fields.id,
			className = fields.className,
			properties = map(fields.properties or "{}"),
			attributes = map(fields.attributes or "{}"),
		},
	}
end

local function refused(message: string): any
	return { ok = false, error = { path = "", message = message } }
end

describe("decodeMetaFile", function()
	describe("an adjacent meta file", function()
		it("reads every field Rojo's AdjacentMetadata holds", function()
			local text =
				'{"$schema": "s", "id": "a", "ignoreUnknownInstances": true, "properties": {"Tags": ["t"]}, "attributes": {"A": 1}}'

			expect(decodeMetaFile(text, false)).toEqual(meta({
				schema = "s",
				id = "a",
				properties = '{"Tags": ["t"]}',
				attributes = '{"A": 1}',
			}))
		end)

		it("reads null optional fields as absent and defaults missing maps", function()
			local text = '{"$schema": null, "id": null, "ignoreUnknownInstances": null}'

			expect(decodeMetaFile(text, false)).toEqual(meta({}))
		end)

		it("ignores unknown fields, a className and fields spelled in another case", function()
			local text = '{"unknown": 1, "className": 5, "Properties": {"Bogus": 1}}'

			expect(decodeMetaFile(text, false)).toEqual(meta({}))
		end)

		it("reads an array of three to five items by position", function()
			expect(decodeMetaFile('[null, "aid", null]', false)).toEqual(meta({ id = "aid" }))
			expect(decodeMetaFile('[null, "aid", null, {"Tags": ["four"]}]', false)).toEqual(meta({
				id = "aid",
				properties = '{"Tags": ["four"]}',
			}))
			expect(decodeMetaFile('[null, "aid", false, {"Tags": ["t"]}, {"A": 1}]', false)).toEqual(meta({
				id = "aid",
				properties = '{"Tags": ["t"]}',
				attributes = '{"A": 1}',
			}))
		end)

		for _, case in ADJACENT_REFUSALS do
			local name, text, message = table.unpack(case)

			it(`refuses {name} in serde's words`, function()
				expect(decodeMetaFile(text, false)).toEqual(refused(message))
			end)
		end
	end)

	describe("a directory meta file", function()
		it("reads className besides the adjacent fields", function()
			local text = '{"className": "StringValue", "properties": {"Value": "hi"}}'

			expect(decodeMetaFile(text, true)).toEqual(meta({
				className = "StringValue",
				properties = '{"Value": "hi"}',
			}))
		end)

		it("reads a null className as absent", function()
			expect(decodeMetaFile('{"className": null}', true)).toEqual(meta({}))
		end)

		it("reads an array of six items by position", function()
			expect(decodeMetaFile('[null, null, null, {}, {}, "Model"]', true)).toEqual(meta({ className = "Model" }))
		end)

		for _, case in DIRECTORY_REFUSALS do
			local name, text, message = table.unpack(case)

			it(`refuses {name} in serde's words`, function()
				expect(decodeMetaFile(text, true)).toEqual(refused(message))
			end)
		end
	end)
end)
