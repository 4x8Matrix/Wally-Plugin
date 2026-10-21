local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoSemver = require(ReplicatedStorage.WallyPlugin.Packages.CargoSemver)
local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local formatPackageReq = require(ReplicatedStorage.WallyPlugin.PluginUtilities.formatPackageReq)
local parsePackageReq = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parsePackageReq)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("parsePackageReq", function()
	it("new", function()
		local request = parsePackageReq("foo/bar@1.2.3").value

		expect(request.name.scope).toBe("foo")
		expect(request.name.name).toBe("bar")
		expect(request.versionReq == CargoSemver.VersionReq.parse("1.2.3")).toBe(true)
	end)

	it("display", function()
		expect(formatPackageReq(parsePackageReq("hello/world@0.2.3").value)).toBe("hello/world@>=0.2.3, <0.3.0")
	end)

	it("parse", function()
		local defaultCompat = parsePackageReq("hello/world@1.2.3").value
		local withOps = parsePackageReq("hello/world@>=0.2.0, <0.2.7").value

		expect(defaultCompat.name.scope).toBe("hello")
		expect(defaultCompat.name.name).toBe("world")
		expect(defaultCompat.versionReq == CargoSemver.VersionReq.parse("^1.2.3")).toBe(true)
		expect(withOps.name.scope).toBe("hello")
		expect(withOps.name.name).toBe("world")
		expect(withOps.versionReq == CargoSemver.VersionReq.parse(">=0.2.0, <0.2.7")).toBe(true)
	end)

	it("parse_invalid", function()
		expect(parsePackageReq("hello/world").ok).toBe(false)
		expect(parsePackageReq("hello/world@").ok).toBe(false)
		expect(parsePackageReq("hello/world@   ").error.message).toBe(
			"a package requirement is of the form SCOPE/NAME@VERSION_REQ"
		)
	end)

	it("serialization", function()
		local serialized = HttpService:JSONEncode(formatPackageReq(parsePackageReq("lpghatguy/asink@2.3.1").value))

		expect(serialized).toBe('"lpghatguy/asink@>=2.3.1, <3.0.0"')
		expect(formatPackageReq(parsePackageReq(HttpService:JSONDecode(serialized)).value)).toBe(
			"lpghatguy/asink@>=2.3.1, <3.0.0"
		)
	end)
end)
