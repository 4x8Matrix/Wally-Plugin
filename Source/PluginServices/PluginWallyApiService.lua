local HttpService = game:GetService("HttpService")

local Console = require(script.Parent.Parent.Packages.Console)
local Promise = require(script.Parent.Parent.Packages.Promise)
local RateLimit = require(script.Parent.Parent.Packages.RateLimit)

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
		local response = HttpService:RequestAsync({
			Url = `{WALLY_API}/{endpoint}`,
			Method = method,
			Headers = {
				["Wally-Version"] = WALLY_VERSION
			}
		})

		if not response.Success then
			reject(response.StatusMessage)
		
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
	
	This function will yield the metadata of every version of a package, in order to get a package versioned metadata,
		please use the `PluginWallyApiService.QueryPackageVersionMetadataAsync` method.
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
	Sends a request to `https://api.wally.run/v1/package-metadata/<scope>/<name>` to fetch metadata on a versioned package.
	
	This function specifically piggy-backs off of `PluginWallyApiService.QueryPackageMetadataAsync` because it fetches metadata
		of a specific version of a package, instead of fetching metadata of all versions of a package.

	Example of metadata from the 'Red' network package:
		{
			["dependencies"] =  ▼  {
				["Clock"] = "red-blox/clock@>=1.0.0, <2.0.0",
				["Future"] = "red-blox/future@>=1.0.0, <2.0.0",
				["Guard"] = "red-blox/guard@>=1.0.0, <2.0.0",
				["Spawn"] = "red-blox/spawn@>=1.0.0, <2.0.0"
			},
			["dev-dependencies"] = {},
			["package"] =  ▼  {
				["authors"] = {},
				["exclude"] =  ▼  {
					[1] = "**"
				},
				["include"] =  ▼  {
					[1] = "default.project.json",
					[2] = "lib",
					[3] = "lib/**",
					[4] = "LICENSE",
					[5] = "wally.toml",
					[6] = "README.md"
				},
				["license"] = "MIT",
				["name"] = "red-blox/red",
				["private"] = false,
				["realm"] = "shared",
				["registry"] = "https://github.com/UpliftGames/wally-index",
				["version"] = "2.1.0"
			},
			["place"] = {},
			["server-dependencies"] = {}
		}
]]
function PluginWallyApiService.QueryPackageVersionMetadataAsync(self: PluginWallyApiService, scope: string, package: string, version: string)
	return Promise.new(function(resolve, reject)
		self:QueryPackageMetadataAsync(scope, package):andThen(function(packageMetaData)
			local packageVersionMetadata

			warn(packageMetaData)

			for _, versionPackageMetaData in packageMetaData.versions do
				if versionPackageMetaData.package.version == version then
					packageVersionMetadata = versionPackageMetaData
		
					break
				end
			end

			resolve(packageVersionMetadata)
		end):catch(reject)
	end)
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