local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local requirementFor = require(ReplicatedStorage.WallyPlugin.PluginUtilities.requirementFor)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local versions = { "3.0.0-rc.2", "3.0.0-rc.1", "2.0.3", "2.0.0", "1.5.0", "1.4.2", "1.4.0", "0.4.3", "0.4.2" }

describe("requirementFor", function()
	it("asks for the chosen version with ^ when that is what ^ resolves to", function()
		expect(requirementFor("2.0.3", versions)).toBe("^2.0.3")
		expect(requirementFor("1.5.0", versions)).toBe("^1.5.0")
		expect(requirementFor("0.4.3", versions)).toBe("^0.4.3")
	end)

	it("pins an older version that ^ would resolve past", function()
		expect(requirementFor("1.4.2", versions)).toBe("=1.4.2")
		expect(requirementFor("2.0.0", versions)).toBe("=2.0.0")
		expect(requirementFor("0.4.2", versions)).toBe("=0.4.2")
	end)

	it("pins a prerelease that a later prerelease would replace", function()
		expect(requirementFor("3.0.0-rc.1", versions)).toBe("=3.0.0-rc.1")
		expect(requirementFor("3.0.0-rc.2", versions)).toBe("^3.0.0-rc.2")
	end)

	it("pins a version semver cannot read", function()
		expect(requirementFor("junk", versions)).toBe("=junk")
	end)
end)
