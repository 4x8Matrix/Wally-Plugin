local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Promise = require(ReplicatedStorage.WallyPlugin.Packages.Promise)

local fixture = require(ReplicatedStorage.Tests.Fixtures.registryMetadata)

local PluginWallyApiService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginWallyApiService)

local parsePackageReq = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parsePackageReq)

local MISSING_BODY = "{\"message\":\"could not open package biff/nope from index\\n\\nCaused by:\\n    0: failed to open file `/tmp/.tmprW8RPG/biff/nope`\\n    1: No such file or directory (os error 2)\"}"

local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local reporter = PluginWallyApiService.Reporter
local requestAsync = PluginWallyApiService.RequestAsync
local requests = { }
local warnings = { }

local function answerWith(handler: (endpoint: string) -> any)
	table.clear(requests)

	PluginWallyApiService.RequestAsync = function(_, method: string, endpoint: string)
		table.insert(requests, `{method} {endpoint}`)

		return handler(endpoint)
	end
end

describe("PluginWallyApiService", function()
	afterEach(function()
		PluginWallyApiService.RequestAsync = requestAsync
		PluginWallyApiService.Reporter = reporter
	end)

	it("reads every version of a package", function()
		answerWith(function()
			return Promise.resolve(HttpService:JSONEncode(fixture.trove))
		end)

		local manifests = PluginWallyApiService:GetPackageMetadataAsync("sleitnick", "trove"):expect()

		expect(#manifests).toBe(#fixture.trove.versions)
		expect(tostring(manifests[1].package.version)).toBe(fixture.trove.versions[1].package.version)
		expect(requests).toEqual({ "GET package-metadata/sleitnick/trove" })
	end)

	it("skips a version Wally's semver cannot read and warns once", function()
		local versions = table.clone(fixture.trove.versions)
		local unreadable = table.clone(fixture.trove.versions[1])

		unreadable.package = table.clone(unreadable.package)
		unreadable.package.version = "0.0.0-001"
		table.insert(versions, unreadable)
		table.clear(warnings)

		PluginWallyApiService.Reporter = {
			Warn = function(_, message: string)
				table.insert(warnings, message)
			end
		}

		answerWith(function()
			return Promise.resolve(HttpService:JSONEncode({ versions = versions }))
		end)

		local manifests = PluginWallyApiService:GetPackageMetadataAsync("sleitnick", "trove"):expect()

		expect(#manifests).toBe(#fixture.trove.versions)
		expect(tostring(manifests[#manifests].package.version)).toBe(
			fixture.trove.versions[#fixture.trove.versions].package.version
		)
		expect(#warnings).toBe(1)
		expect(warnings[1]).toContain("sleitnick/trove@0.0.0-001")
	end)

	it("treats a 404, and the registry's 500 for a package absent from its index, as not found", function()
		answerWith(function()
			return Promise.reject({ statusCode = 404, statusMessage = "Not Found", body = "" })
		end)

		local _, notFound = PluginWallyApiService:GetPackageMetadataAsync("biff", "nope"):await()

		answerWith(function()
			return Promise.reject({ statusCode = 500, statusMessage = "Internal Server Error", body = MISSING_BODY })
		end)

		local _, absent = PluginWallyApiService:GetPackageMetadataAsync("biff", "nope"):await()

		expect(notFound.kind).toBe("PackageNotFound")
		expect(notFound.message).toBe("Failed to find a source for biff/nope")
		expect(absent.kind).toBe("PackageNotFound")
	end)

	it("reports any other failure as the registry being unavailable", function()
		answerWith(function()
			return Promise.reject({ statusCode = 0, statusMessage = "Http requests are not enabled", body = "" })
		end)

		local _, failure = PluginWallyApiService:GetPackageMetadataAsync("sleitnick", "trove"):await()

		expect(failure.kind).toBe("RegistryUnavailable")
		expect(failure.message).toBe("the registry did not answer: 0 Http requests are not enabled")
	end)

	it("carries the registry's answer body when it has one", function()
		answerWith(function()
			return Promise.reject({ statusCode = 503, statusMessage = "Service Unavailable", body = "overloaded" })
		end)

		local _, failure = PluginWallyApiService:GetPackageMetadataAsync("sleitnick", "trove"):await()

		expect(failure.kind).toBe("RegistryUnavailable")
		expect(failure.message).toBe("the registry did not answer: 503 Service Unavailable: overloaded")
	end)

	it("serves the resolver from one request per package", function()
		answerWith(function()
			return Promise.resolve(HttpService:JSONEncode(fixture.trove))
		end)

		local source = PluginWallyApiService:CreatePackageSource()
		local exact = source.query(parsePackageReq("sleitnick/trove@=1.8.0").value)
		local range = source.query(parsePackageReq("sleitnick/trove@>=1.0.0, <2.0.0").value)

		expect(#exact.value).toBe(1)
		expect(#range.value > 1).toBe(true)
		expect(requests).toEqual({ "GET package-metadata/sleitnick/trove" })
	end)
end)
