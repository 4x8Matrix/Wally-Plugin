local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeJsonc = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeJsonc)
local decodeSyncRule = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeSyncRule)

local USES = {
	"csv",
	"jsonModel",
	"json",
	"serverScript",
	"clientScript",
	"moduleScript",
	"pluginScript",
	"legacyClientScript",
	"legacyServerScript",
	"runContextServerScript",
	"runContextClientScript",
	"project",
	"rbxm",
	"rbxmx",
	"toml",
	"text",
	"yaml",
	"ignore",
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function decode(text: string): any
	return decodeSyncRule(decodeJsonc(text).value)
end

local function refusal(text: string): string
	local result = decode(text)

	expect(result.ok).toBe(false)

	return result.error.message
end

describe("decodeSyncRule", function()
	it("compiles `pattern` and `exclude` and keeps `use` and `suffix`, ignoring unknown keys", function()
		local rule = decode('{"pattern": "src/*.dat", "exclude": "src/b.*", "use": "text", "suffix": ".dat", "x": 1}')

		expect(rule.ok).toBe(true)
		expect(rule.value.use).toBe("text")
		expect(rule.value.suffix).toBe(".dat")
		expect(rule.value.matches("src/a.dat")).toBe(true)
		expect(rule.value.matches("lib/a.dat")).toBe(false)
		expect(rule.value.excludes("src/b.dat")).toBe(true)
	end)

	it("reads a null `exclude` or `suffix` as absent", function()
		local rule = decode('{"pattern": "*.x", "use": "text", "exclude": null, "suffix": null}').value

		expect(rule.excludes).toBe(nil)
		expect(rule.suffix).toBe(nil)
	end)

	it("accepts every file middleware Rojo 7.7.1 names, also written as a unit variant object", function()
		for _, use in USES do
			expect(decode(`\{"pattern": "*.x", "use": "{use}"}`).value.use).toBe(use)
		end

		expect(decode('{"pattern": "*.x", "use": {"text": null}}').value.use).toBe("text")
	end)

	it("reads a rule written as an array of its four fields", function()
		local rule = decode('["*.x", null, "text", null]').value

		expect(rule.use).toBe("text")
		expect(rule.matches("a.x")).toBe(true)
		expect(refusal('["*.x", null, "text"]')).toBe("invalid length 3, expected struct SyncRule with 4 elements")
		expect(refusal('["*.x", null, "text", null, 1]')).toBe("invalid length 5, expected fewer elements in array")
	end)

	it("refuses a missing `pattern` or `use`, and a null one", function()
		expect(refusal('{"use": "text"}')).toBe("missing field `pattern`")
		expect(refusal('{"pattern": "*.x"}')).toBe("missing field `use`")
		expect(refusal('{"pattern": null, "use": "text"}')).toBe("invalid type: null, expected a string")
		expect(refusal('{"pattern": "*.x", "use": null}')).toBe("invalid type: null, expected variant identifier")
	end)

	it("refuses a directory middleware, a wrongly cased one and an object with a value", function()
		local expected = table.concat(USES, "`, `")

		expect(refusal('{"pattern": "*.x", "use": "dir"}')).toBe(
			`unknown variant \`dir\`, expected one of \`{expected}\``
		)
		expect(refusal('{"pattern": "*.x", "use": "Text"}')).toBe(
			`unknown variant \`Text\`, expected one of \`{expected}\``
		)
		expect(refusal('{"pattern": "*.x", "use": {"text": 1}}')).toBe(
			"invalid type: integer `1`, expected unit variant"
		)
	end)

	it("refuses a field of the wrong type and a glob globset refuses", function()
		expect(refusal('{"pattern": 1, "use": "text"}')).toBe("invalid type: integer `1`, expected a string")
		expect(refusal('{"pattern": "*.x", "use": "text", "suffix": 1}')).toBe(
			"invalid type: integer `1`, expected a string"
		)
		expect(refusal('{"pattern": "[a", "use": "text"}')).toBe(
			"error parsing glob '[a': unclosed character class; missing ']'"
		)
		expect(refusal('{"pattern": "*.x", "exclude": "[a", "use": "text"}')).toBe(
			"error parsing glob '[a': unclosed character class; missing ']'"
		)
		expect(refusal('"*.x"')).toBe('invalid type: string "*.x", expected struct SyncRule')
	end)
end)
