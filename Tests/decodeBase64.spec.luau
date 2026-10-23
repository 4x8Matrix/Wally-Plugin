local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local decodeBase64 = require(ReplicatedStorage.WallyPlugin.PluginUtilities.decodeBase64)

local DECODED = {
	{ "aGk=", "hi" },
	{ "aGk", "hi" },
	{ "YQ", "a" },
	{ "YQ=", "a" },
	{ "YQ==", "a" },
	{ "", "" },
	{ "YWJj", "abc" },
	{ "YWJjZA", "abcd" },
	{ "YWJjZA=", "abcd" },
	{ "YWJjZA==", "abcd" },
}

local REFUSED = { "a!b=", "YR==", "Y", "aGk==", "-_8=", "aG k=", "YQ=x", "aG=k", "=", "YQ==YQ==", "Y===", "YQ===" }

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("decodeBase64", function()
	for _, case in DECODED do
		it(`decodes "{case[1]}" as Rojo 7.7.1 does`, function()
			expect(decodeBase64(case[1])).toEqual({ ok = true, value = case[2] })
		end)
	end

	for _, text in REFUSED do
		it(`refuses "{text}" as Rojo 7.7.1 does`, function()
			local decoded = decodeBase64(text)

			expect(decoded.ok).toBe(false)
			expect(decoded.error.path).toBe("")
			expect(string.match(decoded.error.message, "is not valid base64")).toBe("is not valid base64")
		end)
	end
end)
