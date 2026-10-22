local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local sortVersions = require(ReplicatedStorage.WallyPlugin.PluginUtilities.sortVersions)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("sortVersions", function()
	it("puts the newest version first by semver precedence", function()
		expect(sortVersions({ "1.0.0", "2.0.0-rc.1", "1.10.0", "1.2.0" })).toEqual({
			"2.0.0-rc.1",
			"1.10.0",
			"1.2.0",
			"1.0.0",
		})
	end)

	it("puts a release ahead of its own prereleases", function()
		expect(sortVersions({ "1.0.0-rc.1", "1.0.0", "1.0.0-rc.10" })).toEqual({ "1.0.0", "1.0.0-rc.10", "1.0.0-rc.1" })
	end)

	it("drops versions semver cannot read", function()
		expect(sortVersions({ "junk", "0.3.1", "" })).toEqual({ "0.3.1" })
	end)

	it("leaves the list it was given alone", function()
		local versions = { "1.0.0", "2.0.0" }

		sortVersions(versions)

		expect(versions).toEqual({ "1.0.0", "2.0.0" })
	end)
end)
