local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local instanceNameForFile = require(ReplicatedStorage.WallyPlugin.PluginUtilities.instanceNameForFile)

local SUFFIX_CASES = {
	{ "x.server.lua", ".server.lua", "x" },
	{ ".server.lua", ".server.lua", "" },
	{ "cfg.data.txt", ".data.txt", "cfg" },
	{ "w.weird", ".nope", "w.weird" },
	{ "e.weird", "", "e.weird" },
}
local STEM_CASES = {
	{ "g.spec.lua", "g.spec" },
	{ "a.b.toml", "a.b" },
	{ "wally.toml", "wally" },
	{ ".lua", ".lua" },
	{ ".foo.lua", ".foo" },
	{ "..lua", "." },
	{ "a.", "a" },
	{ "b.c.d", "b.c" },
	{ "noext", "noext" },
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("instanceNameForFile", function()
	for _, case in SUFFIX_CASES do
		local fileName, suffix, name = table.unpack(case)

		it(`names {fileName} with the suffix "{suffix}" {name}`, function()
			expect(instanceNameForFile(fileName, suffix)).toBe(name)
		end)
	end

	for _, case in STEM_CASES do
		local fileName, name = table.unpack(case)

		it(`names {fileName} without a suffix by its stem, {name}`, function()
			expect(instanceNameForFile(fileName)).toBe(name)
		end)
	end
end)
