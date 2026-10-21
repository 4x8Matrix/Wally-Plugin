local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CargoSemver = require(ReplicatedStorage.WallyPlugin.Packages.CargoSemver)
local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local formatPackageId = require(ReplicatedStorage.WallyPlugin.PluginUtilities.formatPackageId)
local parsePackageId = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parsePackageId)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("parsePackageId", function()
	it("new", function()
		local id = parsePackageId("foo/bar@1.2.3").value

		expect(id.name.scope).toBe("foo")
		expect(id.name.name).toBe("bar")
		expect(id.version:cmp_precedence(CargoSemver.Version.parse("1.2.3"))).toBe(CargoSemver.Ordering.Equal)
	end)

	it("display", function()
		expect(formatPackageId(parsePackageId("hello/world@0.2.3").value)).toBe("hello/world@0.2.3")
	end)

	it("parse", function()
		local hello = parsePackageId("hello/world@1.2.3").value

		expect(hello.name.scope).toBe("hello")
		expect(hello.name.name).toBe("world")
		expect(tostring(hello.version)).toBe("1.2.3")
	end)

	it("parse_invalid", function()
		expect(parsePackageId("hello/world").ok).toBe(false)
		expect(parsePackageId("hello/world@").ok).toBe(false)
		expect(parsePackageId("foo/bar@2").ok).toBe(false)
	end)

	it("serialization", function()
		local serialized = HttpService:JSONEncode(formatPackageId(parsePackageId("lpghatguy/asink@2.3.1").value))

		expect(serialized).toBe('"lpghatguy/asink@2.3.1"')
		expect(formatPackageId(parsePackageId(HttpService:JSONDecode(serialized)).value)).toBe("lpghatguy/asink@2.3.1")
	end)
end)
