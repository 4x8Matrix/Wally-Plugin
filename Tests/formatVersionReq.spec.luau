local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoSemver = require(ReplicatedStorage.WallyPlugin.Packages.CargoSemver)
local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local formatVersionReq = require(ReplicatedStorage.WallyPlugin.PluginUtilities.formatVersionReq)

local CASES = {
	{ "1.2.3", ">=1.2.3, <2.0.0" },
	{ "^1.2.3", ">=1.2.3, <2.0.0" },
	{ "^0.2.3", ">=0.2.3, <0.3.0" },
	{ "^0.0.3", ">=0.0.3, <0.0.4" },
	{ "^1.2", ">=1.2.0, <2.0.0" },
	{ "^0.2", ">=0.2.0, <0.3.0" },
	{ "^0.0", ">=0.0.0, <0.1.0" },
	{ "^1", ">=1.0.0, <2.0.0" },
	{ "^0", ">=0.0.0, <1.0.0" },
	{ "~1.2.3", ">=1.2.3, <1.3.0" },
	{ "~1.2", ">=1.2.0, <1.3.0" },
	{ "~1", ">=1.0.0, <2.0.0" },
	{ "~0.2.3", ">=0.2.3, <0.3.0" },
	{ "=1.2.3", "=1.2.3" },
	{ "=1.2", ">=1.2.0, <1.3.0" },
	{ "=1", ">=1.0.0, <2.0.0" },
	{ ">1.2.3", ">1.2.3" },
	{ ">1.2", ">1.2.0" },
	{ ">1", ">1.0.0" },
	{ ">=1.2.3", ">=1.2.3" },
	{ ">=1.2", ">=1.2.0" },
	{ ">=1", ">=1.0.0" },
	{ "<1.2.3", "<1.2.3" },
	{ "<1.2", "<1.2.0" },
	{ "<1", "<1.0.0" },
	{ "<=1.2.3", "<=1.2.3" },
	{ "<=1.2", "<1.3.0" },
	{ "<=1", "<2.0.0" },
	{ "*", ">=0.0.0" },
	{ "1.*", ">=1.0.0, <2.0.0" },
	{ "1.2.*", ">=1.2.0, <1.3.0" },
	{ "1.x", ">=1.0.0, <2.0.0" },
	{ "^1.0.0-rc.1", ">=1.0.0-rc.1, <2.0.0" },
	{ "~1.2.3-beta", ">=1.2.3-beta, <1.3.0" },
	{ "=1.0.0-rc.1", "=1.0.0-rc.1" },
	{ ">=4.0.0-rc.0, <5.0.0", ">=4.0.0-rc.0, <5.0.0" },
	{ "1.2.3, <1.5.0", ">=1.2.3, <2.0.0, <1.5.0" },
	{ "  1.2.3  ", ">=1.2.3, <2.0.0" },
	{ "0.0.0", ">=0.0.0, <0.0.1" },
	{ "^0.0.0", ">=0.0.0, <0.0.1" }
}

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("formatVersionReq", function()
	it("prints every requirement the way semver 0.11 does", function()
		for _, case in CASES do
			expect(formatVersionReq(CargoSemver.VersionReq.parse(case[1]))).toBe(case[2])
		end
	end)
end)
