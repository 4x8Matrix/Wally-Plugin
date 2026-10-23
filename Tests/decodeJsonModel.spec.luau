local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeJsonModel = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonModel)
local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)

local REFUSALS = {
	{ "both spellings of name", '{"name": "a", "Name": "b", "className": "Folder"}', "duplicate field `name`" },
	{
		"both spellings of className",
		'{"className": "Folder", "ClassName": "Model"}',
		"duplicate field `className`",
	},
	{
		"both spellings of properties",
		'{"className": "Folder", "properties": {}, "Properties": {}}',
		"duplicate field `properties`",
	},
	{
		"both spellings of children",
		'{"className": "Folder", "children": [], "Children": []}',
		"duplicate field `children`",
	},
	{
		"both spellings of a child's name",
		'{"className": "Folder", "children": [{"className": "Folder", "name": "a", "Name": "b"}]}',
		"duplicate field `name`",
	},
	{ "a missing className", '{"name": "x"}', "missing field `className`" },
	{ "an empty object", "{}", "missing field `className`" },
	{
		"a child without className",
		'{"className": "Folder", "children": [{"name": "x"}]}',
		"missing field `className`",
	},
	{ "a null className", '{"className": null}', "invalid type: null, expected a &str" },
	{ "a number for className", '{"className": 1}', "invalid type: integer `1`, expected a &str" },
	{
		"a number for the top-level name",
		'{"className": "Folder", "name": 1}',
		"invalid type: integer `1`, expected a string",
	},
	{
		"a number for a child's name",
		'{"className": "Folder", "children": [{"className": "Folder", "name": 1}]}',
		"invalid type: integer `1`, expected a string",
	},
	{
		"a negative number for a child's name",
		'{"className": "Folder", "children": [{"className": "Folder", "name": -2}]}',
		"invalid type: integer `-2`, expected a string",
	},
	{
		"a fraction for a child's name",
		'{"className": "Folder", "children": [{"className": "Folder", "name": 1.5}]}',
		"invalid type: floating point `1.5`, expected a string",
	},
	{
		"a boolean for a child's name",
		'{"className": "Folder", "children": [{"className": "Folder", "name": false}]}',
		"invalid type: boolean `false`, expected a string",
	},
	{
		"an object for a child's name",
		'{"className": "Folder", "children": [{"className": "Folder", "name": {}}]}',
		"invalid type: map, expected a string",
	},
	{ "an object for children", '{"className": "Folder", "children": {}}', "invalid type: map, expected a sequence" },
	{ "a null children", '{"className": "Folder", "children": null}', "invalid type: null, expected a sequence" },
	{
		"an array for properties",
		'{"className": "Folder", "properties": []}',
		"invalid type: sequence, expected a map",
	},
	{ "a null properties", '{"className": "Folder", "properties": null}', "invalid type: null, expected a map" },
	{ "a null attributes", '{"className": "Folder", "attributes": null}', "invalid type: null, expected a map" },
	{
		"a number for the top-level id",
		'{"className": "Folder", "id": 5}',
		"invalid type: integer `5`, expected a string",
	},
	{
		"a number for a child's id",
		'{"className": "Folder", "children": [{"className": "Folder", "id": 5}]}',
		"invalid type: integer `5`, expected a string",
	},
	{ "a number for $schema", '{"$schema": 5, "className": "Folder"}', "invalid type: integer `5`, expected a string" },
	{ "a string for the model", '"Folder"', 'invalid type: string "Folder", expected struct JsonModel' },
	{ "a number for the model", "5", "invalid type: integer `5`, expected struct JsonModel" },
	{ "a null for the model", "null", "invalid type: null, expected struct JsonModel" },
	{ "a boolean for the model", "true", "invalid type: boolean `true`, expected struct JsonModel" },
	{
		"a string for a child",
		'{"className": "Folder", "children": ["Folder"]}',
		'invalid type: string "Folder", expected struct JsonModel',
	},
	{
		"a null for a child",
		'{"className": "Folder", "children": [null]}',
		"invalid type: null, expected struct JsonModel",
	},
	{ "an empty array", "[]", "invalid length 0, expected struct JsonModel with 7 elements" },
	{ "an array of three", '[null, null, "Folder"]', "invalid length 3, expected struct JsonModel with 7 elements" },
	{
		"an array of eight",
		'[null, null, "Folder", null, [], {}, {}, 1]',
		"invalid length 8, expected fewer elements in array",
	},
	{ "an array holding a null className", "[null, null, null, null]", "invalid type: null, expected a &str" },
	{
		"an array holding a null children",
		'[null, null, "Folder", null, null]',
		"invalid type: null, expected a sequence",
	},
	{ "only a comment", "// nothing here", "File contains no JSON value" },
}
local UNPARSED = {
	{ "invalid JSON", '{"className": "Folder",, }' },
	{ "two values", '{"className": "Folder"} {"className": "Folder"}' },
	{ "a leading byte order mark", '\u{FEFF}{"className": "Folder"}' },
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function data(text: string): any
	local decoded = decodeJsonc(text)

	assert(decoded.ok, text)

	return decoded.value
end

local function model(fields: { [string]: any }): any
	return {
		name = fields.name,
		className = fields.className,
		id = fields.id,
		properties = fields.properties or data("{}"),
		attributes = fields.attributes or data("{}"),
		children = fields.children or {},
	}
end

local function decoded(fields: { [string]: any }): any
	return { ok = true, value = model(fields) }
end

describe("decodeJsonModel", function()
	describe("the schema (R1.10)", function()
		it("reads every field", function()
			local text = [[{
				"$schema": "https://example.com/model.json",
				"name": "Top",
				"className": "Model",
				"id": "top",
				"properties": {"Tags": ["a"]},
				"attributes": {"Speed": 5},
				"children": [{"className": "Part", "name": "Base", "id": "base"}]
			}]]

			expect(decodeJsonModel(text)).toEqual(decoded({
				name = "Top",
				className = "Model",
				id = "top",
				properties = data('{"Tags": ["a"]}'),
				attributes = data('{"Speed": 5}'),
				children = { model({ name = "Base", className = "Part", id = "base" }) },
			}))
		end)

		it("reads Name, ClassName, Properties and Children as aliases", function()
			local text =
				'{"ClassName": "Model", "Properties": {"Tags": ["a"]}, "Children": [{"ClassName": "Part", "Name": "P", "Properties": {"Anchored": true}}]}'

			expect(decodeJsonModel(text)).toEqual(decoded({
				className = "Model",
				properties = data('{"Tags": ["a"]}'),
				children = {
					model({ name = "P", className = "Part", properties = data('{"Anchored": true}') }),
				},
			}))
		end)

		it("reads Name at the top level as the name", function()
			expect(decodeJsonModel('{"Name": "Other", "className": "Folder"}')).toEqual(
				decoded({ name = "Other", className = "Folder" })
			)
		end)

		it("keeps the last of a key written twice, as serde_json's map does", function()
			expect(decodeJsonModel('{"className": "Model", "className": "Folder"}')).toEqual(
				decoded({ className = "Folder" })
			)
		end)

		it("ignores unknown fields, Attributes among them", function()
			expect(decodeJsonModel('{"className": "Folder", "tags": ["x"], "foo": 1, "Attributes": {"A": 1}}')).toEqual(
				decoded({ className = "Folder" })
			)
		end)

		it("reads a null $schema, name or id as absent", function()
			expect(decodeJsonModel('{"$schema": null, "name": null, "id": null, "className": "Folder"}')).toEqual(
				decoded({ className = "Folder" })
			)
		end)

		it("keeps children in written order", function()
			local text =
				'{"className": "Folder", "children": [{"className": "Part"}, {"className": "Part", "name": "Named"}, {"className": "Folder", "name": "Part"}]}'

			expect(decodeJsonModel(text)).toEqual(decoded({
				className = "Folder",
				children = {
					model({ className = "Part" }),
					model({ name = "Named", className = "Part" }),
					model({ name = "Part", className = "Folder" }),
				},
			}))
		end)

		it("reads JSONC", function()
			local text =
				'// a comment\n{\n\tclassName: "Folder", /* inline */\n\t"children": [{"className": "Part",},],\n}'

			expect(decodeJsonModel(text)).toEqual(
				decoded({ className = "Folder", children = { model({ className = "Part" }) } })
			)
		end)
	end)

	describe("an array, which serde reads field by field", function()
		it("reads four fields: $schema, name, className and id", function()
			expect(decodeJsonModel('[null, null, "Folder", null]')).toEqual(decoded({ className = "Folder" }))
		end)

		it("reads children as the fifth", function()
			expect(decodeJsonModel('[null, null, "Folder", "top", [{"className": "Part"}]]')).toEqual(
				decoded({ className = "Folder", id = "top", children = { model({ className = "Part" }) } })
			)
		end)

		it("reads properties and attributes as the sixth and seventh", function()
			expect(decodeJsonModel('[null, "N", "StringValue", null, [], {"Value": "v"}, {"A": 1}]')).toEqual(decoded({
				name = "N",
				className = "StringValue",
				properties = data('{"Value": "v"}'),
				attributes = data('{"A": 1}'),
			}))
		end)

		it("reads a child written as an array", function()
			local text = '{"className": "Folder", "children": [[null, "Kid", "Folder", null, [], {}, {}]]}'

			expect(decodeJsonModel(text)).toEqual(
				decoded({ className = "Folder", children = { model({ name = "Kid", className = "Folder" }) } })
			)
		end)
	end)

	describe("a blank file", function()
		for _, text in { "", " \n\t \r\n ", "\u{A0}\u{3000}", "\n\u{2028}\u{85}" } do
			it(`gives no model for {string.format("%q", text)}`, function()
				expect(decodeJsonModel(text)).toEqual({ ok = true })
			end)
		end
	end)

	describe("refusals, in Rojo 7.7.1's words", function()
		for _, refusal in REFUSALS do
			it(`refuses {refusal[1]}`, function()
				expect(decodeJsonModel(refusal[2])).toEqual({ ok = false, error = { path = "", message = refusal[3] } })
			end)
		end

		it("refuses a file that is not UTF-8", function()
			expect(decodeJsonModel('{"className": "Folder\255"}')).toEqual({
				ok = false,
				error = { path = "", message = "File was not valid UTF-8" },
			})
		end)

		for _, case in UNPARSED do
			it(`refuses {case[1]} as decodeJsonc does`, function()
				expect(decodeJsonModel(case[2])).toEqual(decodeJsonc(case[2]))
				expect(decodeJsonModel(case[2]).ok).toBe(false)
			end)
		end
	end)
end)
