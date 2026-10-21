local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoSemver = require(ReplicatedStorage.WallyPlugin.Packages.CargoSemver)
local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local fixture = require(ReplicatedStorage.Tests.Fixtures.indexRequirements)

local TIMEOUT_MILLISECONDS = 120000

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function parseVersions(target: string, texts: { string }, dropped: { string }): { any }
	local versions = { }

	for _, text in texts do
		local readable, version = pcall(CargoSemver.Version.parse, text)

		if readable then
			table.insert(versions, version)
		else
			table.insert(dropped, `{target}@{text}`)
		end
	end

	return versions
end

local function bestMatch(versionReq: any, versions: { any }): string
	local best

	for _, version in versions do
		if
			versionReq:matches(version) and (not best or version:cmp_precedence(best) == CargoSemver.Ordering.Greater)
		then
			best = version
		end
	end

	return if best then tostring(best) else ""
end

describe("cargo-semver against Wally's semver 0.11", function()
	it("picks the same best version for every requirement in the index", function()
		local versionsByTarget = { }
		local mismatches = { }
		local dropped = { }

		for target, texts in fixture.versions do
			versionsByTarget[target] = parseVersions(target, texts, dropped)
		end

		for _, case in fixture.cases do
			local target, text, expected = case[1], case[2], case[3]
			local parsed, versionReq = pcall(CargoSemver.VersionReq.parse, text)
			local actual = if parsed then bestMatch(versionReq, versionsByTarget[target]) else "error"

			if actual ~= expected then
				table.insert(
					mismatches,
					`{target}@{text}: semver 0.11 picks '{expected}', cargo-semver picks '{actual}'`
				)
			end
		end

		expect(#fixture.cases).toBe(4172)
		expect(dropped).toEqual({ })
		expect(mismatches).toEqual({ })
	end, TIMEOUT_MILLISECONDS)
end)
