local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local fixture = require(ReplicatedStorage.Tests.Fixtures.registryMetadata)

local formatPackageReq = require(ReplicatedStorage.WallyPlugin.PluginUtilities.formatPackageReq)
local parseRegistryManifest = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parseRegistryManifest)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("parseRegistryManifest", function()
	it("reads every version of a real registry answer", function()
		for _, entry in fixture.trove.versions do
			local parsed = parseRegistryManifest(entry)

			expect(parsed.ok).toBe(true)
			expect(parsed.value.package.name.name).toBe("trove")
			expect(tostring(parsed.value.package.version)).toBe(entry.package.version)
		end
	end)

	it("keeps dependency requirements in Wally's printed form", function()
		local roactRodux

		for _, entry in fixture.roactRodux.versions do
			if entry.package.version == "0.5.1" then
				roactRodux = parseRegistryManifest(entry).value
			end
		end

		expect(formatPackageReq(roactRodux.dependencies.Rodux)).toBe("roblox/rodux@>=4.0.0-rc.0, <5.0.0")
		expect(formatPackageReq(roactRodux.dependencies.Roact)).toBe("roblox/roact@>=1.4.0, <2.0.0")
		expect(roactRodux.package.realm).toBe("shared")
		expect(roactRodux.package.registry).toBe("https://github.com/UpliftGames/wally-index")
	end)

	it("treats missing dependency tables as empty", function()
		local parsed = parseRegistryManifest({ package = { name = "foo/bar", version = "1.0.0", realm = "server" } })

		expect(parsed.ok).toBe(true)
		expect(next(parsed.value.dependencies)).toBe(nil)
		expect(parsed.value.package.registry).toBe("")
	end)

	it("refuses entries it cannot read", function()
		expect(parseRegistryManifest({ }).error.kind).toBe("RegistryUnavailable")
		expect(parseRegistryManifest({ package = { name = "foo/bar", version = "1", realm = "shared" } }).ok).toBe(
			false
		)
		expect(parseRegistryManifest({ package = { name = "Foo/bar", version = "1.0.0", realm = "shared" } }).ok).toBe(
			false
		)
		expect(parseRegistryManifest({ package = { name = "foo/bar", version = "1.0.0", realm = "client" } }).ok).toBe(
			false
		)
		expect(parseRegistryManifest({
			package = { name = "foo/bar", version = "1.0.0", realm = "shared" },
			dependencies = { A = "nope" }
		}).ok).toBe(false)
		expect(parseRegistryManifest({
			package = { name = "foo/bar", version = "1.0.0", realm = "shared" },
			dependencies = { A = 5 }
		}).ok).toBe(false)
	end)
end)
