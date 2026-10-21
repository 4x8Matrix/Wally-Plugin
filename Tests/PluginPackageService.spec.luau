local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Promise = require(ReplicatedStorage.WallyPlugin.Packages.Promise)

local InMemoryRegistry = require(ReplicatedStorage.Tests.Doubles.InMemoryRegistry)
local PackageBuilder = require(ReplicatedStorage.Tests.Doubles.PackageBuilder)
local PluginActionService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginActionService)
local PluginPackageService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginPackageService)

local writeManifestSource = require(ReplicatedStorage.WallyPlugin.PluginUtilities.writeManifestSource)

local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local registry
local messages
local recordings
local shared
local server
local failureCases = {
	{
		kind = "InvalidRequest",
		title = "a package name Wally refuses",
		run = function()
			return PluginPackageService:InstallAsync("Biff/minimal", "shared")
		end,
		message = "package scope 'Biff' is invalid (scopes can only contain lowercase characters, digits and '-')"
	},
	{
		kind = "InvalidRequest",
		title = "a requirement semver cannot read",
		run = function()
			return PluginPackageService:InstallAsync("biff/minimal", "shared", "not a version")
		end
	},
	{
		kind = "PackageNotFound",
		title = "a package the registry does not have",
		prepare = function()
			PluginPackageService.Registry.CreatePackageSource = function()
				return {
					query = function()
						return {
							ok = false,
							error = { kind = "PackageNotFound", message = "Failed to find a source for biff/minimal" }
						}
					end
				}
			end
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/minimal", "shared", "^1.0.0")
		end,
		message = "Failed to find a source for biff/minimal@>=1.0.0, <2.0.0"
	},
	{
		kind = "NoMatchingVersion",
		title = "a requirement no version meets",
		run = function()
			return PluginPackageService:InstallAsync("biff/minimal", "shared", "^9.0.0")
		end,
		message = "No packages were found that matched (Shared) biff/minimal@>=9.0.0, <10.0.0.\nAre you sure this is a Shared dependency?"
	},
	{
		kind = "Conflict",
		title = "two packages needing incompatible copies",
		prepare = function()
			registry:Publish(PackageBuilder.new("biff/pinned@1.0.0"):WithDependency("Minimal", "biff/minimal@=1.0.0"))
			PluginPackageService:InstallAsync("biff/pinned", "shared"):expect()
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/other", "shared")
		end,
		message = "All possible candidates for package biff/minimal@=1.0.0 (Shared) conflicted with other packages that were already installed. These packages were previously selected: biff/minimal@1.0.0"
	},
	{
		kind = "RegistryUnavailable",
		title = "a registry that does not answer",
		prepare = function()
			PluginPackageService.Registry.CreatePackageSource = function()
				return {
					query = function()
						return {
							ok = false,
							error = {
								kind = "RegistryUnavailable",
								message = "the registry did not answer: 0 Http requests are not enabled"
							}
						}
					end
				}
			end
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/minimal", "shared", "^1.0.0")
		end,
		message = "the registry did not answer: 0 Http requests are not enabled"
	},
	{
		kind = "DownloadFailed",
		title = "a package whose contents are missing",
		prepare = function()
			registry:Publish(PackageBuilder.new("biff/no-zip@1.0.0"))
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/no-zip", "shared")
		end,
		message = "biff/no-zip@1.0.0 could not be downloaded: the registry answered 404 Not Found"
	},
	{
		kind = "BuildFailed",
		title = "a package the serialiser cannot build",
		prepare = function()
			registry:Publish(PackageBuilder.new("biff/broken@1.0.0"))
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/broken", "shared")
		end,
		message = "biff/broken@1.0.0 could not be built: "
	},
	{
		kind = "NameClash",
		title = "a root link name the plugin did not write",
		prepare = function()
			local packages = Instance.new("Folder")
			local foreign = Instance.new("ModuleScript")

			packages.Name = "Packages"
			packages.Parent = shared
			foreign.Name = "Minimal"
			foreign.Parent = packages
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/minimal", "shared")
		end,
		message = "ReplicatedStorage.Packages.Minimal already exists and was not written by the Wally plugin"
	},
	{
		kind = "NameClash",
		title = "a Packages that is not a Folder",
		prepare = function()
			local packages = Instance.new("Configuration")

			packages.Name = "Packages"
			packages.Parent = server
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/minimal", "shared")
		end,
		message = "ServerStorage.Packages exists and is not a Folder"
	},
	{
		kind = "ManifestUnreadable",
		title = "a manifest edited into something else",
		prepare = function()
			PluginPackageService:InstallAsync("biff/minimal", "shared"):expect()

			shared.Packages._Plugin_Index.Manifest_DO_NOT_MODIFY.Source = "return 5"
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/other", "shared")
		end,
		message = "ReplicatedStorage.Packages._Plugin_Index.Manifest_DO_NOT_MODIFY could not be read and was left as it is"
	},
	{
		kind = "Busy",
		title = "Studio recording another change",
		prepare = function()
			PluginPackageService.Recorder.Begin = function()
				return
			end
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/minimal", "shared")
		end,
		message = "Studio is recording another change; try again once it finishes"
	},
	{
		kind = "Unexpected",
		title = "a registry source that throws",
		prepare = function()
			PluginPackageService.Registry.CreatePackageSource = function()
				return {
					query = function()
						error("the source broke")
					end
				}
			end
		end,
		run = function()
			return PluginPackageService:InstallAsync("biff/minimal", "shared", "^1.0.0")
		end
	}
}

local function tree(...: Instance): { string }
	local lines = { }

	for _, root in { ... } do
		for _, descendant in root:GetDescendants() do
			local source = if descendant:IsA("ModuleScript") then descendant.Source else ""

			table.insert(lines, `{descendant:GetFullName()} {descendant.ClassName} {source}`)
		end
	end

	table.sort(lines)

	return lines
end

local function folderNames(index: Instance): { string }
	local names = { }

	for _, child in index:GetChildren() do
		if child:IsA("Folder") then
			table.insert(names, child.Name)
		end
	end

	table.sort(names)

	return names
end

local function failuresOf(promise): { any }
	local succeeded, problems = promise:await()

	expect(succeeded).toBe(false)

	return problems
end

describe("PluginPackageService", function()
	beforeEach(function()
		registry = InMemoryRegistry.new()
		messages = { }
		recordings = { }
		shared = Instance.new("Folder")
		server = Instance.new("Folder")
		shared.Name = "ReplicatedStorage"
		server.Name = "ServerStorage"

		registry:Publish(PackageBuilder.new("biff/minimal@1.0.0"))
		registry:Publish(PackageBuilder.new("biff/minimal@1.1.0"))
		registry:Publish(PackageBuilder.new("biff/minimal@2.0.0-rc.1"))
		registry:Publish(
			PackageBuilder.new("biff/one-dependency@1.0.0"):WithDependency("Minimal", "biff/minimal@1.0.0")
		)
		registry:Publish(PackageBuilder.new("biff/other@1.0.0"):WithDependency("Minimal", "biff/minimal@1.1.0"))
		registry:Publish(
			PackageBuilder.new("biff/server@1.0.0"):WithRealm("server"):WithDependency("Minimal", "biff/minimal@1.0.0")
		)

		PluginPackageService.Locations = { shared = shared, server = server }
		PluginPackageService.ActiveOperation = nil
		PluginPackageService.Registry = {
			CreatePackageSource = function()
				return registry:Source()
			end,
			GetPackageMetadataAsync = function(_, scope: string, name: string)
				return Promise.resolve(registry:Manifests(scope, name))
			end,
			DownloadPackageZipAsync = function(_, scope: string, name: string, version: string)
				if name == "no-zip" then
					return Promise.reject({ statusCode = 404, statusMessage = "Not Found", body = "" })
				end

				return Promise.resolve(`{scope}/{name}@{version}`)
			end
		}
		PluginPackageService.Serialiser = {
			SerialiseZipIntoRobloxInstances = function(_, zip: string)
				local module = Instance.new("ModuleScript")

				if string.find(zip, "broken", 1, true) then
					error("bad project file")
				end

				module.Source = `return "{zip}"`

				if string.find(zip, "locked", 1, true) then
					module:Destroy()
				end

				return module
			end
		}
		PluginPackageService.Recorder = {
			Begin = function(name: string)
				table.insert(recordings, `begin {name}`)

				return "recording"
			end,
			Finish = function(_, commit: boolean)
				table.insert(recordings, if commit then "commit" else "cancel")
			end
		}
		PluginPackageService.Reporter = {
			Log = function(_, message: string)
				table.insert(messages, message)
			end,
			Warn = function(_, message: string)
				table.insert(messages, message)
			end,
			Error = function(_, message: string)
				table.insert(messages, message)
			end
		}
	end)

	it("creates nothing in the place when required", function()
		expect(PluginPackageService.OnInit).toBe(nil)
		expect(PluginPackageService.OnStart).toBe(nil)
		expect(#ServerStorage:GetChildren()).toBe(0)
		expect(#ReplicatedStorage:GetChildren()).toBe(3)
		expect(ReplicatedStorage.Packages:FindFirstChild("_Plugin_Index")).toBe(nil)
	end)

	it("installs a package and its dependency in Wally's layout", function()
		local summary = PluginPackageService:InstallAsync("biff/one-dependency", "shared"):expect()
		local packages = shared.Packages
		local index = packages._Plugin_Index

		expect(summary.added).toBe(2)
		expect(summary.kept).toBe(0)
		expect(summary.id).toBe("biff/one-dependency@1.0.0")
		expect(summary.rootLink).toBe(packages.OneDependency)
		expect(packages.OneDependency.Source).toBe(
			'return require(script.Parent._Plugin_Index["biff_one-dependency@1.0.0"]["one-dependency"])\n'
		)
		expect(index["biff_one-dependency@1.0.0"].Minimal.Source).toBe(
			'return require(script.Parent.Parent["biff_minimal@1.1.0"]["minimal"])\n'
		)
		expect(index["biff_minimal@1.1.0"].minimal.Source).toBe('return "biff/minimal@1.1.0"')
		expect(index.Manifest_DO_NOT_MODIFY.Source).toBe(
			writeManifestSource({ FormatVersion = 1, Dependencies = { OneDependency = "biff/one-dependency@^1.0.0" } })
		)
		expect(recordings).toEqual({ "begin Install of biff/one-dependency", "commit" })
		expect(messages).toEqual({
			"Installed biff/one-dependency@1.0.0 as OneDependency: 2 packages (2 added, 0 already present)."
		})
		expect(PluginActionService:IsActionActive("DownloadingPackage")).toBe(false)
		expect(PluginPackageService.ActiveOperation).toBe(nil)
	end)

	it("installs the newest stable version when no requirement is given", function()
		PluginPackageService:InstallAsync("biff/minimal", "shared"):expect()

		expect(folderNames(shared.Packages._Plugin_Index)).toEqual({ "biff_minimal@1.1.0" })
		expect(shared.Packages._Plugin_Index.Manifest_DO_NOT_MODIFY.Source).toBe(
			writeManifestSource({ FormatVersion = 1, Dependencies = { Minimal = "biff/minimal@^1.1.0" } })
		)
	end)

	it("changes nothing when the same package is installed again", function()
		PluginPackageService:InstallAsync("biff/minimal", "shared"):expect()

		local before = tree(shared, server)
		local summary = PluginPackageService:InstallAsync("biff/minimal", "shared"):expect()

		expect(summary.added).toBe(0)
		expect(summary.kept).toBe(1)
		expect(tree(shared, server)).toEqual(before)
	end)

	it("keeps what is installed and shares one compatible copy", function()
		PluginPackageService:InstallAsync("biff/one-dependency", "shared"):expect()

		local summary = PluginPackageService:InstallAsync("biff/other", "shared"):expect()

		expect(folderNames(shared.Packages._Plugin_Index)).toEqual({
			"biff_minimal@1.1.0",
			"biff_one-dependency@1.0.0",
			"biff_other@1.0.0"
		})
		expect(summary.added).toBe(1)
		expect(summary.kept).toBe(2)
	end)

	it("removes a package and only the dependencies nothing else needs", function()
		PluginPackageService:InstallAsync("biff/one-dependency", "shared"):expect()
		PluginPackageService:InstallAsync("biff/other", "shared"):expect()

		local summary = PluginPackageService:RemoveAsync("OneDependency", "shared"):expect()

		expect(summary.removed).toBe(1)
		expect(folderNames(shared.Packages._Plugin_Index)).toEqual({ "biff_minimal@1.1.0", "biff_other@1.0.0" })
		expect(shared.Packages:FindFirstChild("OneDependency")).toBe(nil)
		expect(messages[#messages]).toBe("Removed OneDependency: 1 removed, 2 still installed.")
	end)

	it("removes its own folders with the last package and leaves a CLI _Index alone", function()
		local cli = Instance.new("Folder")

		PluginPackageService:InstallAsync("biff/minimal", "shared"):expect()
		PluginPackageService:RemoveAsync("Minimal", "shared"):expect()

		expect(shared:FindFirstChild("Packages")).toBe(nil)

		PluginPackageService:InstallAsync("biff/minimal", "shared"):expect()

		cli.Name = "_Index"
		cli.Parent = shared.Packages

		PluginPackageService:RemoveAsync("Minimal", "shared"):expect()

		expect(shared.Packages:GetChildren()).toEqual({ cli })
	end)

	it("installs a server package and its shared dependency in the server realm", function()
		PluginPackageService:InstallAsync("biff/server", "server"):expect()

		local index = server.Packages._Plugin_Index

		expect(folderNames(index)).toEqual({ "biff_minimal@1.1.0", "biff_server@1.0.0" })
		expect(index["biff_server@1.0.0"].Minimal.Source).toBe(
			'return require(script.Parent.Parent["biff_minimal@1.1.0"]["minimal"])\n'
		)
		expect(server.Packages.Server.Source).toBe(
			'return require(script.Parent._Plugin_Index["biff_server@1.0.0"]["server"])\n'
		)
		expect(shared:FindFirstChild("Packages")).toBe(nil)
	end)

	it("keeps a server root link into the shared realm readable, listed and removable", function()
		PluginPackageService:InstallAsync("biff/one-dependency", "shared"):expect()
		PluginPackageService:InstallAsync("biff/minimal", "server"):expect()

		expect(server.Packages.Minimal.Source).toBe(
			'return require(game.ReplicatedStorage.Packages._Plugin_Index["biff_minimal@1.1.0"]["minimal"])\n'
		)

		PluginPackageService:InstallAsync("biff/other", "shared"):expect()

		expect(PluginPackageService:GetInstalled()[1]).toEqual({
			alias = "Minimal",
			realm = "server",
			requirement = "biff/minimal@^1.1.0",
			id = "biff/minimal@1.1.0"
		})

		PluginPackageService:RemoveAsync("Minimal", "server"):expect()

		expect(#server:GetChildren()).toBe(0)
		expect(folderNames(shared.Packages._Plugin_Index)).toEqual({
			"biff_minimal@1.1.0",
			"biff_one-dependency@1.0.0",
			"biff_other@1.0.0"
		})
	end)

	it("leaves an empty Packages folder it did not create", function()
		local packages = Instance.new("Folder")

		packages.Name = "Packages"
		packages.Parent = server

		PluginPackageService:InstallAsync("biff/minimal", "shared"):expect()

		expect(server:GetChildren()).toEqual({ packages })
	end)

	it("unparents what a removal takes out so an undo can bring it back", function()
		PluginPackageService:InstallAsync("biff/minimal", "shared"):expect()

		local packages = shared.Packages
		local index = packages._Plugin_Index
		local folder = index["biff_minimal@1.1.0"]
		local link = packages.Minimal

		PluginPackageService:RemoveAsync("Minimal", "shared"):expect()

		local restored = pcall(function()
			link.Parent = packages
			folder.Parent = index
			index.Parent = packages
			packages.Parent = shared
		end)

		expect(restored).toBe(true)
		expect(shared.Packages.Minimal).toBe(link)
		expect(shared.Packages._Plugin_Index["biff_minimal@1.1.0"]).toBe(folder)
	end)

	it("checks the place again once the recording begins", function()
		local foreign = Instance.new("ModuleScript")

		PluginPackageService.Recorder.Begin = function(name: string)
			local packages = Instance.new("Folder")

			packages.Name = "Packages"
			packages.Parent = shared
			foreign.Name = "Minimal"
			foreign.Source = "return 1"
			foreign.Parent = packages

			table.insert(recordings, `begin {name}`)

			return "recording"
		end

		local problems = failuresOf(PluginPackageService:InstallAsync("biff/minimal", "shared"))

		expect(problems[1].kind).toBe("NameClash")
		expect(foreign.Source).toBe("return 1")
		expect(shared.Packages:GetChildren()).toEqual({ foreign })
		expect(recordings).toEqual({ "begin Install of biff/minimal", "cancel" })
	end)

	it("lists what is installed", function()
		PluginPackageService:InstallAsync("biff/one-dependency", "shared"):expect()
		PluginPackageService:InstallAsync("biff/server", "server"):expect()

		expect(PluginPackageService:GetInstalled()).toEqual({
			{
				alias = "OneDependency",
				realm = "shared",
				requirement = "biff/one-dependency@^1.0.0",
				id = "biff/one-dependency@1.0.0"
			},
			{ alias = "Server", realm = "server", requirement = "biff/server@^1.0.0", id = "biff/server@1.0.0" }
		})
	end)

	it("refuses to start while another operation runs", function()
		PluginPackageService.ActiveOperation = "Install of biff/other"

		local problems = failuresOf(PluginPackageService:InstallAsync("biff/minimal", "shared"))

		expect(problems[1].kind).toBe("Busy")
		expect(problems[1].message).toBe("Install of biff/other is still running")
		expect(PluginPackageService.ActiveOperation).toBe("Install of biff/other")
		expect(shared:FindFirstChild("Packages")).toBe(nil)
	end)

	it("reports every package that failed to download or build at once", function()
		registry:Publish(PackageBuilder.new("biff/no-zip@1.0.0"))
		registry:Publish(PackageBuilder.new("biff/broken@1.0.0"))
		registry:Publish(
			PackageBuilder.new("biff/pair@1.0.0")
				:WithDependency("Broken", "biff/broken@1.0.0")
				:WithDependency("NoZip", "biff/no-zip@1.0.0")
		)

		local problems = failuresOf(PluginPackageService:InstallAsync("biff/pair", "shared"))
		local kinds = { }

		for _, problem in problems do
			table.insert(kinds, problem.kind)
		end

		table.sort(kinds)

		expect(kinds).toEqual({ "BuildFailed", "DownloadFailed" })
		expect(shared:FindFirstChild("Packages")).toBe(nil)
	end)

	it("cancels the recording when writing to the place fails", function()
		registry:Publish(PackageBuilder.new("biff/locked@1.0.0"))

		local problems = failuresOf(PluginPackageService:InstallAsync("biff/locked", "shared"))

		expect(problems[1].kind).toBe("CommitFailed")
		expect(recordings).toEqual({ "begin Install of biff/locked", "cancel" })
		expect(PluginActionService:IsActionActive("DownloadingPackage")).toBe(false)
	end)

	for _, case in failureCases do
		it(`reports {case.kind} for {case.title} and leaves the place as it was`, function()
			if case.prepare then
				case.prepare()
			end

			local before = tree(shared, server)
			local problems = failuresOf(case.run())

			expect(problems[1].kind).toBe(case.kind)
			expect(messages[#messages]).toContain("failed; the place was not changed.")
			expect(messages[#messages]).toContain(`\n  {case.kind}: {case.message or ""}`)
			expect(tree(shared, server)).toEqual(before)
			expect(PluginActionService:IsActionActive("DownloadingPackage")).toBe(false)
			expect(PluginPackageService.ActiveOperation).toBe(nil)
		end)
	end
end)
