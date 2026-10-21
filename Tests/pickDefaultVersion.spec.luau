local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local pickDefaultVersion = require(ReplicatedStorage.WallyPlugin.PluginUtilities.pickDefaultVersion)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("pickDefaultVersion, the registry website's rule", function()
	it("prefers the newest version without a prerelease", function()
		expect(pickDefaultVersion({ "4.0.0-rc.0", "3.0.0" }).value).toBe("3.0.0")
		expect(pickDefaultVersion({ "0.0.1", "17.0.1-rc.16", "17.0.1-rc.18", "17.0.1-rc.19" }).value).toBe("0.0.1")
		expect(
			pickDefaultVersion({
				"17.3.7",
				"17.3.8",
				"17.3.9",
				"17.3.10",
				"17.3.11-pre.1",
				"17.3.11-pre.2",
				"17.3.11-pre.3",
				"17.3.11-pre.4"
			}).value
		).toBe("17.3.10")
	end)

	it("falls back to the newest prerelease", function()
		expect(pickDefaultVersion({ "1.0.0-rc.1", "1.0.0-rc.10", "1.0.0-rc.2" }).value).toBe("1.0.0-rc.10")
	end)

	it("skips versions it cannot read", function()
		expect(pickDefaultVersion({ "nope", "1.2.3" }).value).toBe("1.2.3")
	end)

	it("fails when nothing is published", function()
		expect(pickDefaultVersion({ }).error.kind).toBe("NoMatchingVersion")
	end)
end)
