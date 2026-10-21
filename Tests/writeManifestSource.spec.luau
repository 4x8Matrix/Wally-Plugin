local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local writeManifestSource = require(ReplicatedStorage.WallyPlugin.PluginUtilities.writeManifestSource)

local HEADER = "-- Written by the Wally plugin from the installed requests; rewritten on every install and removal."

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local manifest = {
	FormatVersion = 1,
	Dependencies = { Trove = "sleitnick/trove@^1.8.0", RoactRodux = "roblox/roact-rodux@^0.5.1" }
}

describe("writeManifestSource", function()
	it("writes sorted entries in a stable form", function()
		expect(writeManifestSource(manifest)).toBe(table.concat({
			HEADER,
			"return {",
			"\tFormatVersion = 1,",
			"\tDependencies = {",
			'\t\t["RoactRodux"] = "roblox/roact-rodux@^0.5.1",',
			'\t\t["Trove"] = "sleitnick/trove@^1.8.0"',
			"\t}",
			"}",
			""
		}, "\n"))
	end)

	it("loads back to the same table", function()
		expect(loadstring(writeManifestSource(manifest))()).toEqual(manifest)
	end)

	it("leaves out empty sections", function()
		expect(writeManifestSource({ FormatVersion = 1, ServerDependencies = { } })).toBe(
			`{HEADER}\nreturn \{\n\tFormatVersion = 1\n}\n`
		)
	end)
end)
