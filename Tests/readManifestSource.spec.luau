local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local readManifestSource = require(ReplicatedStorage.WallyPlugin.PluginUtilities.readManifestSource)
local writeManifestSource = require(ReplicatedStorage.WallyPlugin.PluginUtilities.writeManifestSource)

local HEADER = "-- Written by the Wally plugin from the installed requests; rewritten on every install and removal."

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local manifests = {
	{
		FormatVersion = 1,
		Dependencies = { Trove = "sleitnick/trove@^1.8.0", RoactRodux = "roblox/roact-rodux@^0.5.1" }
	},
	{ FormatVersion = 1, ServerDependencies = { Server = "biff/server@^1.0.0" } },
	{
		FormatVersion = 1,
		Dependencies = { Trove = "sleitnick/trove@^1.8.0" },
		ServerDependencies = { Server = "biff/server@^1.0.0", Other = "biff/other@=1.0.0" }
	},
	{ FormatVersion = 1, Dependencies = { ['we"ird\\alias'] = "biff/minimal@^1.0.0" } },
	{ FormatVersion = 1 }
}

local function refusedFor(lines: { string })
	local read = readManifestSource(table.concat(lines, "\n") .. "\n")

	expect(read.ok).toBe(false)
	expect(read.error.kind).toBe("ManifestUnreadable")
end

describe("readManifestSource", function()
	it("reads back every table writeManifestSource writes", function()
		for _, manifest in manifests do
			expect(readManifestSource(writeManifestSource(manifest))).toEqual({ ok = true, value = manifest })
		end
	end)

	it("reads a section the writer leaves out as absent", function()
		expect(readManifestSource(writeManifestSource({ FormatVersion = 1, ServerDependencies = { } }))).toEqual({
			ok = true,
			value = { FormatVersion = 1 }
		})
	end)

	it("refuses source that is not a manifest table", function()
		expect(readManifestSource("return 5").ok).toBe(false)
		expect(readManifestSource("").ok).toBe(false)

		refusedFor({ "return {", "\tFormatVersion = 1", "}" })
		refusedFor({ HEADER, "return {", "}" })
	end)

	it("refuses a function call, which is data to read and never code to run", function()
		refusedFor({
			HEADER,
			"return {",
			"\tFormatVersion = 1,",
			"\tDependencies = {",
			'\t\t["Trove"] = tostring("sleitnick/trove@^1.8.0")',
			"\t}",
			"}"
		})
		refusedFor({ HEADER, "return {", "\tFormatVersion = os.time()", "}" })
	end)

	it("refuses an unknown or repeated key", function()
		refusedFor({
			HEADER,
			"return {",
			"\tFormatVersion = 1,",
			"\tDevDependencies = {",
			'\t\t["Trove"] = "sleitnick/trove@^1.8.0"',
			"\t}",
			"}"
		})
		refusedFor({
			HEADER,
			"return {",
			"\tFormatVersion = 1,",
			"\tDependencies = {",
			'\t\t["Trove"] = "sleitnick/trove@^1.8.0"',
			"\t},",
			"\tDependencies = {",
			'\t\t["Other"] = "biff/other@^1.0.0"',
			"\t}",
			"}"
		})
	end)

	it("refuses a requirement that is not a string", function()
		refusedFor({
			HEADER,
			"return {",
			"\tFormatVersion = 1,",
			"\tDependencies = {",
			'\t\t["Trove"] = 5',
			"\t}",
			"}"
		})
	end)
end)
