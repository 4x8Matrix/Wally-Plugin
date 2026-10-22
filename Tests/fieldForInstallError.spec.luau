local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local fieldForInstallError = require(ReplicatedStorage.WallyPlugin.PluginUtilities.fieldForInstallError)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local cases = {
	{
		"name",
		"NameClash",
		"ReplicatedStorage.Packages.Minimal already exists and was not written by the Wally plugin",
	},
	{ "name", "NameClash", "Minimal is already installed in the server realm" },
	{ "general", "NameClash", "ServerStorage.Packages exists and is not a Folder" },
	{
		"version",
		"NoMatchingVersion",
		"No packages were found that matched (Shared) biff/minimal@>=9.0.0, <10.0.0.\nAre you sure this is a Shared dependency?",
	},
	{ "version", "InvalidRequest", "could not parse version requirement: not a version" },
	{
		"general",
		"InvalidRequest",
		"package scope 'Biff' is invalid (scopes can only contain lowercase characters, digits and '-')",
	},
	{ "general", "DownloadFailed", "biff/no-zip@1.0.0 could not be downloaded: the registry answered 404 Not Found" },
	{ "general", "Busy", "Studio is recording another change; try again once it finishes" },
}

describe("fieldForInstallError", function()
	for _, case in cases do
		local field, kind, message = table.unpack(case)

		it(`puts {kind} "{string.sub(message, 1, 40)}" under {field}`, function()
			expect(fieldForInstallError({ kind = kind, message = message })).toBe(field)
		end)
	end
end)
