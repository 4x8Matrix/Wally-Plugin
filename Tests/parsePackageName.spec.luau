local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local formatPackageName = require(ReplicatedStorage.WallyPlugin.PluginUtilities.formatPackageName)
local parsePackageName = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parsePackageName)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("parsePackageName", function()
	it("new", function()
		local package = parsePackageName("flub-flab/sisyphus-simulator-2")

		expect(package.ok).toBe(true)
		expect(package.value.scope).toBe("flub-flab")
		expect(package.value.name).toBe("sisyphus-simulator-2")
	end)

	it("new_invalid", function()
		expect(parsePackageName("Upper-Skewer-Case/Foo").ok).toBe(false)
		expect(parsePackageName("snake_case/foo").ok).toBe(false)
		expect(parsePackageName("hello/world/from/me").ok).toBe(false)
		expect(parsePackageName("/").ok).toBe(false)
	end)

	it("parse", function()
		local adoptMe = parsePackageName("flub-flab/sisyphus-simulator")
		local numbers = parsePackageName("123/456")

		expect(adoptMe.value.scope).toBe("flub-flab")
		expect(adoptMe.value.name).toBe("sisyphus-simulator")
		expect(numbers.value.scope).toBe("123")
		expect(numbers.value.name).toBe("456")
	end)

	it("parse_invalid", function()
		expect(parsePackageName("hello/world/foo").ok).toBe(false)
	end)

	it("display", function()
		expect(formatPackageName(parsePackageName("evaera/promise").value)).toBe("evaera/promise")
	end)

	it("serialization", function()
		local serialized = HttpService:JSONEncode(formatPackageName(parsePackageName("lpghatguy/asink").value))

		expect(serialized).toBe('"lpghatguy/asink"')
		expect(formatPackageName(parsePackageName(HttpService:JSONDecode(serialized)).value)).toBe("lpghatguy/asink")
	end)

	it("reports Wally's messages", function()
		expect(parsePackageName("foo").error.message).toBe("a package name is of the form SCOPE/NAME")
		expect(parsePackageName("snake_case/foo").error.message).toBe(
			"package scope 'snake_case' is invalid (scopes can only contain lowercase characters, digits and '-')"
		)
		expect(parsePackageName("foo/Bar").error.message).toBe(
			"package name 'Bar' is invalid (names can only contain lowercase characters, digits and '-')"
		)
		expect(parsePackageName("/foo").error.message).toBe("package scopes cannot be empty")
		expect(parsePackageName("foo/").error.message).toBe("package names cannot be empty")
		expect(parsePackageName("foo/" .. string.rep("a", 65)).error.message).toBe(
			"package names cannot exceed 64 characters in length"
		)
		expect(parsePackageName("foo").error.kind).toBe("InvalidRequest")
	end)
end)
