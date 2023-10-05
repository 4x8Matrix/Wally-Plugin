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

function PluginWallyApiService.QueryPackageVersionMetadataAsync(self: PluginWallyApiService, scope: string, package: string, version: string)
	return Promise.new(function(resolve, reject)
		self:QueryPackageMetadataAsync(scope, package):andThen(function(packageMetaData)
			local packageVersionMetadata

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