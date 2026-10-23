local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeProjectFile = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeProjectFile)

local TREE = '{"$className": "Folder"}'
local FOLDER = {
	className = "Folder",
	properties = { kind = "map", entries = {} },
	attributes = { kind = "map", entries = {} },
	children = {},
}
local ROOT_FIELDS = "`$schema`, `name`, `tree`, `servePort`, `servePlaceIds`, `blockedPlaceIds`, `placeId`, `gameId`, "
	.. "`serveAddress`, `serveAllowedHosts`, `emitLegacyScripts`, `globIgnorePaths`, `syncbackRules`, `syncRules`"
local SYNCBACK_FIELDS = "`ignoreTrees`, `ignorePaths`, `ignoreProperties`, `syncCurrentCamera`, `syncUnscriptable`, "
	.. "`ignoreReferents`, `createIgnoreDirPaths`"

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function withField(field: string, json: string): string
	return `\{"{field}": {json}, "tree": {TREE}}`
end

local function accepts(text: string)
	local result = decodeProjectFile(text)

	expect({ text, result.ok }).toEqual({ text, true })
end

local function refusal(text: string): string
	local result = decodeProjectFile(text)

	expect({ text, result.ok }).toEqual({ text, false })

	return result.error.message
end

describe("decodeProjectFile", function()
	it("reads the fields that shape a build and leaves defaults where they are absent", function()
		local project = decodeProjectFile('{"name": "N", "tree": {"$className": "Folder"}, "emitLegacyScripts": false}')

		expect(project).toEqual({
			ok = true,
			value = { name = "N", tree = FOLDER, emitLegacyScripts = false, globIgnorePaths = {}, syncRules = {} },
		})
		expect(decodeProjectFile(`\{"tree": {TREE}}`).value).toEqual({
			tree = FOLDER,
			globIgnorePaths = {},
			syncRules = {},
		})
	end)

	it("compiles globIgnorePaths as ignore globs and syncRules as rules, in written order", function()
		local project = decodeProjectFile([=[{
			"tree": {"$className": "Folder"},
			"globIgnorePaths": ["src/*.lua", "!src/keep.lua"],
			"syncRules": [{"pattern": "*.dat", "use": "text"}, ["*.x", null, "moduleScript", ".x"]]
		}]=]).value

		expect(project.globIgnorePaths[1].negated).toBe(false)
		expect(project.globIgnorePaths[1].matches("src/a.lua")).toBe(true)
		expect(project.globIgnorePaths[2].negated).toBe(true)
		expect(project.syncRules[1].use).toBe("text")
		expect(project.syncRules[2].suffix).toBe(".x")
	end)

	it("accepts null for every field without a default, and well-formed serve-only and syncback fields", function()
		for _, field in { "$schema", "name", "emitLegacyScripts", "servePort", "servePlaceIds", "blockedPlaceIds" } do
			accepts(withField(field, "null"))
		end

		for _, field in { "placeId", "gameId", "serveAddress", "syncbackRules" } do
			accepts(withField(field, "null"))
		end

		accepts(withField("servePort", "65535"))
		accepts(withField("servePort", "0x1F"))
		accepts(withField("placeId", "9007199254740992"))
		accepts(withField("servePlaceIds", "[1, 1]"))
		accepts(withField("serveAddress", '"127.0.0.1"'))
		accepts(withField("serveAddress", '"::ffff:1.2.3.4"'))
		accepts(withField("serveAllowedHosts", '["a", "b"]'))
		accepts(withField("globIgnorePaths", '["\\\\!x"]'))
		accepts(withField("syncbackRules", "{}"))
		accepts(withField("syncbackRules", '{"ignorePaths": ["[a"], "syncCurrentCamera": null}'))
		accepts(withField(
			"syncbackRules",
			HttpService:JSONEncode({
				ignoreTrees = { "a" },
				ignorePaths = { "b" },
				ignoreProperties = { Part = { "Size" } },
				syncCurrentCamera = true,
				syncUnscriptable = false,
				ignoreReferents = true,
				createIgnoreDirPaths = false,
			})
		))
	end)

	it("reads a project written as an array of its fields, as serde reads a sequence", function()
		local fields = `null, "N", {TREE}, null, null, null, null, null, null, [], null, []`

		expect(decodeProjectFile(`[{fields}, null]`).value.name).toBe("N")
		expect(refusal(`[null, "N", {TREE}]`)).toBe("invalid length 3, expected struct Project with 14 elements")
		expect(refusal(`[{fields}, null, [], 1]`)).toBe("invalid length 15, expected fewer elements in array")
	end)

	it("refuses text that is not one JSONC value", function()
		expect(refusal("{")).toBe(decodeProjectFile("{").error.message)
		expect(refusal("")).toBe("File contains no JSON value")
		expect(refusal(`\{"tree": {TREE}} \{}`)).toBe("Text cannot contain more than one JSON value around 36")
		expect(refusal(`\{"name": "\255", "tree": {TREE}}`)).toBe("File is not valid UTF-8")
		expect(refusal('"x"')).toBe('invalid type: string "x", expected struct Project')
	end)

	it("refuses an unknown root field, a missing or null tree and a tree that is not an object", function()
		expect(refusal(withField("foo", "1"))).toBe(`unknown field \`foo\`, expected one of {ROOT_FIELDS}`)
		expect(refusal('{"name": "x"}')).toBe("missing field `tree`")
		expect(refusal('{"tree": null}')).toBe("invalid type: null, expected struct ProjectNode")
		expect(refusal('{"tree": []}')).toBe("invalid type: sequence, expected struct ProjectNode")
	end)

	it("refuses null for the fields with a default", function()
		for _, field in { "serveAllowedHosts", "globIgnorePaths", "syncRules" } do
			expect(refusal(withField(field, "null"))).toBe("invalid type: null, expected a sequence")
		end
	end)

	it("refuses a wrong type or an out-of-range number in any root field, serve-only ones included", function()
		expect(refusal(withField("name", "1"))).toBe("invalid type: integer `1`, expected a string")
		expect(refusal(withField("$schema", "1"))).toBe("invalid type: integer `1`, expected a string")
		expect(refusal(withField("emitLegacyScripts", '"yes"'))).toBe('invalid type: string "yes", expected a boolean')
		expect(refusal(withField("servePort", '"x"'))).toBe('invalid type: string "x", expected u16')
		expect(refusal(withField("servePort", "-1"))).toBe("invalid value: integer `-1`, expected u16")
		expect(refusal(withField("servePort", "65536"))).toBe("invalid value: integer `65536`, expected u16")
		expect(refusal(withField("servePort", "1.5"))).toBe("invalid type: floating point `1.5`, expected u16")
		expect(refusal(withField("placeId", "-1"))).toBe("invalid value: integer `-1`, expected u64")
		expect(refusal(withField("gameId", '"1"'))).toBe('invalid type: string "1", expected u64')
		expect(refusal(withField("placeId", "18446744073709551616"))).toBe(
			"invalid type: floating point `18446744073709552000`, expected u64"
		)
		expect(refusal(withField("servePlaceIds", "[-1]"))).toBe("invalid value: integer `-1`, expected u64")
		expect(refusal(withField("blockedPlaceIds", '{"a": 1}'))).toBe("invalid type: map, expected a sequence")
		expect(refusal(withField("servePlaceIds", "1"))).toBe("invalid type: integer `1`, expected a sequence")
		expect(refusal(withField("serveAddress", '"localhost"'))).toBe("invalid IP address syntax")
		expect(refusal(withField("serveAddress", "1"))).toBe("invalid type: integer `1`, expected IP address")
		expect(refusal(withField("serveAllowedHosts", "[1]"))).toBe("invalid type: integer `1`, expected a string")
		expect(refusal(withField("serveAllowedHosts", '"a"'))).toBe('invalid type: string "a", expected a sequence')
	end)

	it("refuses an ignore glob or sync rule that does not read", function()
		expect(refusal(withField("globIgnorePaths", '["src/[a"]'))).toBe(
			"error parsing glob 'src/[a': unclosed character class; missing ']'"
		)
		expect(refusal(withField("globIgnorePaths", "[1]"))).toBe("invalid type: integer `1`, expected a string")
		expect(refusal(withField("syncRules", "[1]"))).toBe("invalid type: integer `1`, expected struct SyncRule")
		expect(refusal(withField("syncRules", '{"a": 1}'))).toBe("invalid type: map, expected a sequence")
		expect(refusal(withField("syncRules", '[{"pattern": "*.x", "use": "dir"}]'))).toMatch("^unknown variant `dir`")
	end)

	it("refuses a malformed syncbackRules, which denies unknown fields", function()
		expect(refusal(withField("syncbackRules", '{"nope": 1}'))).toBe(
			`unknown field \`nope\`, expected one of {SYNCBACK_FIELDS}`
		)
		expect(refusal(withField("syncbackRules", '{"ignoreTrees": null}'))).toBe(
			"invalid type: null, expected a sequence"
		)
		expect(refusal(withField("syncbackRules", '{"ignoreProperties": {"Part": "Size"}}'))).toBe(
			'invalid type: string "Size", expected a sequence'
		)
		expect(refusal(withField("syncbackRules", '{"ignoreReferents": 1}'))).toBe(
			"invalid type: integer `1`, expected a boolean"
		)
		expect(refusal(withField("syncbackRules", "[]"))).toBe(
			"invalid length 3, expected struct SyncbackRules with 7 elements"
		)
	end)
end)
