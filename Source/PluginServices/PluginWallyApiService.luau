local HttpService = game:GetService("HttpService")

local CargoSemver = require(script.Parent.Parent.Packages.CargoSemver)
local Console = require(script.Parent.Parent.Packages.Console)
local Promise = require(script.Parent.Parent.Packages.Promise)
local RateLimit = require(script.Parent.Parent.Packages.RateLimit)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local describeRequestFailure = require(script.Parent.Parent.PluginUtilities.describeRequestFailure)
local parseRegistryManifest = require(script.Parent.Parent.PluginUtilities.parseRegistryManifest)

local WALLY_API = "https://api.wally.run/v1"
local WALLY_VERSION = "0.3.0"

local PluginWallyApiService = { }

PluginWallyApiService.Reporter = Console.new(`🌟 {script.Name}`)

PluginWallyApiService.DownloadRateLimiter = RateLimit(100, 1)
PluginWallyApiService.QueryRateLimiter = RateLimit(100, 1)

--[[
	Base method for any request made under the `PluginWallyApiService`, this service adds the 'Wally-Version' header,
		this header is required to download packages.

	Wally devs! I've just pulled the version you're using from `https://wally.run`, please let me know on Discord if you'd
		like this to be something else!
]]
function PluginWallyApiService.RequestAsync(_: PluginWallyApiService, method: string, endpoint: string)
	return Promise.new(function(resolve, reject)
		local requested, response = pcall(HttpService.RequestAsync, HttpService, {
			Url = `{WALLY_API}/{endpoint}`,
			Method = method,
			Headers = {
				["Wally-Version"] = WALLY_VERSION
			}
		})

		if not requested then
			reject({ statusCode = 0, statusMessage = tostring(response), body = "" })

			return
		end

		if not response.Success then
			reject({ statusCode = response.StatusCode, statusMessage = response.StatusMessage, body = response.Body })

			return
		end

		resolve(response.Body)
	end)
end

--[[
	Sends a request to `https://api.wally.run/v1/package-search?query=<queryText>` in order to query what
		packages are avaliable on the wally backend.
]]
function PluginWallyApiService.QueryWallyApiAsync(self: PluginWallyApiService, queryText: string)
	return Promise.new(function(resolve, reject)
		while not self.QueryRateLimiter() do
			task.wait(1)
		end

		queryText = HttpService:UrlEncode(queryText)

		self:RequestAsync(`GET`, `package-search?query={queryText}`):andThen(function(httpBody)
			resolve(HttpService:JSONDecode(httpBody))
		end):catch(function(...)
			reject(...)
		end)

		return
	end)
end

--[[
	Sends a request to `https://api.wally.run/v1/package-metadata/<scope>/<name>` to fetch metadata on a package.
]]
function PluginWallyApiService.QueryPackageMetadataAsync(self: PluginWallyApiService, scope: string, package: string)
	return Promise.new(function(resolve, reject)
		while not self.QueryRateLimiter() do
			task.wait(1)
		end

		package = HttpService:UrlEncode(package)
		scope = HttpService:UrlEncode(scope)

		self:RequestAsync(`GET`, `package-metadata/{scope}/{package}`):andThen(function(httpBody)
			resolve(HttpService:JSONDecode(httpBody))
		end):catch(function(...)
			reject(...)
		end)

		return
	end)
end

--[[
	Fetches every published version of a package from `package-metadata/<scope>/<name>` as Manifests. A missing
		package rejects as `PackageNotFound`: the registry answers 500 instead of 404 for a package absent from its
		index, so that answer counts as missing too. An entry whose version Wally's semver cannot read is skipped with a
		warning; any other malformed entry rejects the package.
]]
function PluginWallyApiService.GetPackageMetadataAsync(self: PluginWallyApiService, scope: string, name: string)
	return self:QueryPackageMetadataAsync(scope, name):andThen(function(metadata)
		local manifests = { }

		for _, entry in metadata.versions or { } do
			local hasVersion, version = pcall(function()
				local candidate = entry.package.version

				assert(type(candidate) == "string", "the version is not a string")

				return candidate
			end)

			if hasVersion and not pcall(CargoSemver.Version.parse, version) then
				self.Reporter:Warn(`{scope}/{name}@{version} is not a version Wally's semver reads, so it is skipped`)

				continue
			end

			local parsed = parseRegistryManifest(entry)

			if not parsed.ok then
				return Promise.reject(parsed.error)
			end

			table.insert(manifests, parsed.value)
		end

		return manifests
	end, function(failure)
		local status = failure.statusCode or 0
		local missing = status == 404
			or (status == 500 and string.find(failure.body, "could not open package", 1, true))
		local detail = if failure.body and failure.body ~= "" then `: {failure.body}` else ""

		if missing then
			return Promise.reject({
				kind = "PackageNotFound",
				message = `Failed to find a source for {scope}/{name}`,
				package = `{scope}/{name}`
			})
		end

		return Promise.reject({
			kind = "RegistryUnavailable",
			message = `the registry did not answer: {describeRequestFailure(failure)}{detail}`,
			package = `{scope}/{name}`
		})
	end)
end

--[[
	Returns the resolver's view of the registry for one install run: `query` fetches a package's versions the first
		time it is asked for that package, keeps them, and returns those matching the request. It yields while it
		fetches.
]]
function PluginWallyApiService.CreatePackageSource(self: PluginWallyApiService): Types.PackageSource
	local cache = { }

	return {
		query = function(request: Types.PackageReq)
			local key = `{request.name.scope}/{request.name.name}`
			local matching = { }

			if not cache[key] then
				local fetched, value = self:GetPackageMetadataAsync(request.name.scope, request.name.name):await()

				cache[key] = if fetched then { ok = true, value = value } else { ok = false, error = value }
			end

			if not cache[key].ok then
				return cache[key]
			end

			for _, manifest in cache[key].value do
				if request.versionReq:matches(manifest.package.version) then
					table.insert(matching, manifest)
				end
			end

			return { ok = true, value = matching }
		end
	}
end

--[[
	Sends a request to `https://api.wally.run/v1/package-contents/<scope>/<name>/<version>` to recieve the contents of the published package.
		The downloaded package is encoded with the Zip codec, meaning we've got to parse that zip file.
]]
function PluginWallyApiService.DownloadPackageZipAsync(self: PluginWallyApiService, scope: string, name: string, version: string)
	return Promise.new(function(resolve, reject)
		while not self.DownloadRateLimiter() do
			task.wait(1)
		end

		scope = HttpService:UrlEncode(scope)
		name = HttpService:UrlEncode(name)
		version = HttpService:UrlEncode(version)

		self:RequestAsync(`GET`, `package-contents/{scope}/{name}/{version}`):andThen(function(httpBody)
			resolve(httpBody)
		end):catch(function(...)
			reject(...)
		end)

		return
	end)
end

export type PluginWallyApiService = typeof(PluginWallyApiService)

return PluginWallyApiService