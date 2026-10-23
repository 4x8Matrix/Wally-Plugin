local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeFileContents = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeFileContents)

local LEGACY = Enum.RunContext.Legacy
local SERVER = Enum.RunContext.Server
local CLIENT = Enum.RunContext.Client
local PLUGIN = Enum.RunContext.Plugin
local SCRIPT_KINDS = {
	{ use = "serverScript", legacy = "Script", legacyContext = LEGACY, current = "Script", currentContext = SERVER },
	{ use = "clientScript", legacy = "LocalScript", current = "Script", currentContext = CLIENT },
	{ use = "moduleScript", legacy = "ModuleScript", current = "ModuleScript" },
	{ use = "pluginScript", legacy = "Script", legacyContext = PLUGIN, current = "Script", currentContext = PLUGIN },
	{
		use = "legacyServerScript",
		legacy = "Script",
		legacyContext = LEGACY,
		current = "Script",
		currentContext = LEGACY,
	},
	{ use = "legacyClientScript", legacy = "LocalScript", current = "LocalScript" },
	{
		use = "runContextServerScript",
		legacy = "Script",
		legacyContext = SERVER,
		current = "Script",
		currentContext = SERVER,
	},
	{
		use = "runContextClientScript",
		legacy = "Script",
		legacyContext = CLIENT,
		current = "Script",
		currentContext = CLIENT,
	},
}
local INVALID_UTF8 = {
	{ "moduleScript", "File was not valid UTF-8" },
	{ "text", "File was not valid UTF-8" },
	{ "json", "File contains malformed JSON: File is not valid UTF-8" },
	{ "toml", "File contains malformed TOML: source is not valid UTF-8 around 1" },
	{ "yaml", "File was not valid UTF-8" },
	{ "csv", "File was not a valid LocalizationTable CSV file: invalid UTF-8" },
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function decoded(className: string, properties: { [string]: any }): any
	return { ok = true, value = { className = className, properties = properties } }
end

describe("decodeFileContents", function()
	for _, case in SCRIPT_KINDS do
		it(`makes a {case.use} file {case.legacy} with legacy scripts and {case.current} without (R1.3)`, function()
			expect(decodeFileContents("x", case.use, true)).toEqual(decoded(case.legacy, {
				Source = "x",
				RunContext = case.legacyContext,
			}))
			expect(decodeFileContents("x", case.use, false)).toEqual(decoded(case.current, {
				Source = "x",
				RunContext = case.currentContext,
			}))
		end)
	end

	it("turns CRLF into LF in a script, keeping a lone CR and a byte order mark", function()
		expect(decodeFileContents("\u{FEFF}a\r\nb\rc\r\n", "moduleScript", true)).toEqual(decoded("ModuleScript", {
			Source = "\u{FEFF}a\nb\rc\n",
		}))
	end)

	it("keeps a text file's line endings in its StringValue (R1.8)", function()
		expect(decodeFileContents("a\r\nb\r", "text", true)).toEqual(decoded("StringValue", { Value = "a\r\nb\r" }))
	end)

	it("makes a CSV file a LocalizationTable (R1.9)", function()
		expect(decodeFileContents("Key,Source,es\nHi,Hello,Hola\n", "csv", true)).toEqual(decoded("LocalizationTable", {
			Contents = '[{"key":"Hi","source":"Hello","values":{"es":"Hola"}}]',
		}))
	end)

	it("makes JSON, TOML and YAML files modules returning their value (R1.5 to R1.7)", function()
		expect(decodeFileContents('{"b": 1, "a": [true, null]}', "json", true)).toEqual(decoded("ModuleScript", {
			Source = "return {\n\ta = {true, nil},\n\tb = 1,\n}",
		}))
		expect(decodeFileContents("x = 1", "toml", true)).toEqual(decoded("ModuleScript", {
			Source = "return {\n\tx = 1,\n}",
		}))
		expect(decodeFileContents("", "toml", true)).toEqual(decoded("ModuleScript", { Source = "return {\n}" }))
		expect(decodeFileContents("- 1", "yaml", true)).toEqual(decoded("ModuleScript", { Source = "return {1}" }))
	end)

	for _, case in INVALID_UTF8 do
		local use, message = table.unpack(case)

		it(`refuses a {use} file that is not valid UTF-8, naming no path`, function()
			expect(decodeFileContents("a\255", use, true)).toEqual({
				ok = false,
				error = { path = "", message = message },
			})
		end)
	end

	it("refuses an empty JSON file in Rojo's words", function()
		expect(decodeFileContents("", "json", true)).toEqual({
			ok = false,
			error = { path = "", message = "File contains malformed JSON: File contains no JSON value" },
		})
	end)
end)
