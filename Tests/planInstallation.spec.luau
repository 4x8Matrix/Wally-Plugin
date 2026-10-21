local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local InMemoryRegistry = require(ReplicatedStorage.Tests.Doubles.InMemoryRegistry)
local PackageBuilder = require(ReplicatedStorage.Tests.Doubles.PackageBuilder)

local packageFolderName = require(ReplicatedStorage.WallyPlugin.PluginUtilities.packageFolderName)
local parsePackageId = require(ReplicatedStorage.WallyPlugin.PluginUtilities.parsePackageId)
local planInstallation = require(ReplicatedStorage.WallyPlugin.PluginUtilities.planInstallation)
local resolvePackages = require(ReplicatedStorage.WallyPlugin.PluginUtilities.resolvePackages)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("planInstallation", function()
	it("writes Wally's link text with _Plugin_Index", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("place/root@0.0.0")
			:WithDependency("Shared", "biff/shared@1.0.0")
			:WithDependency("B", "biff/b@1.0.0")
			:WithServerDependency("Server", "biff/server@1.0.0")

		registry:Publish(PackageBuilder.new("biff/shared@1.0.0"))
		registry:Publish(
			PackageBuilder.new("biff/server@1.0.0"):WithRealm("server"):WithDependency("Shared", "biff/shared@1.0.0")
		)
		registry:Publish(PackageBuilder.new("biff/d@1.0.0"))
		registry:Publish(PackageBuilder.new("biff/b@1.0.0"):WithDependency("D", "biff/d@1.0.0"))

		local plan =
			planInstallation(resolvePackages(root:Manifest(), { }, registry:Source()).value, "place/root@0.0.0").value

		expect(plan.shared.packages).toEqual({
			["biff_shared@1.0.0"] = "biff/shared@1.0.0",
			["biff_b@1.0.0"] = "biff/b@1.0.0",
			["biff_d@1.0.0"] = "biff/d@1.0.0"
		})
		expect(plan.server.packages).toEqual({ ["biff_server@1.0.0"] = "biff/server@1.0.0" })
		expect(plan.shared.rootLinks).toEqual({
			Shared = 'return require(script.Parent._Plugin_Index["biff_shared@1.0.0"]["shared"])\n',
			B = 'return require(script.Parent._Plugin_Index["biff_b@1.0.0"]["b"])\n'
		})
		expect(plan.server.rootLinks).toEqual({
			Server = 'return require(script.Parent._Plugin_Index["biff_server@1.0.0"]["server"])\n'
		})
		expect(plan.shared.packageLinks["biff_b@1.0.0"]).toEqual({
			D = 'return require(script.Parent.Parent["biff_d@1.0.0"]["d"])\n'
		})
		expect(plan.shared.packageLinks["biff_d@1.0.0"]).toEqual({ })
		expect(plan.server.packageLinks["biff_server@1.0.0"]).toEqual({
			Shared = 'return require(game.ReplicatedStorage.Packages._Plugin_Index["biff_shared@1.0.0"]["shared"])\n'
		})
	end)

	it("places a shared package that only a server package needs in the server realm", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("place/root@0.0.0"):WithServerDependency("Server", "biff/server@1.0.0")

		registry:Publish(PackageBuilder.new("biff/shared@1.0.0"))
		registry:Publish(
			PackageBuilder.new("biff/server@1.0.0"):WithRealm("server"):WithDependency("Shared", "biff/shared@1.0.0")
		)

		local plan =
			planInstallation(resolvePackages(root:Manifest(), { }, registry:Source()).value, "place/root@0.0.0").value

		expect(plan.shared.packages).toEqual({ })
		expect(plan.server.packages).toEqual({
			["biff_server@1.0.0"] = "biff/server@1.0.0",
			["biff_shared@1.0.0"] = "biff/shared@1.0.0"
		})
		expect(plan.server.packageLinks["biff_server@1.0.0"]).toEqual({
			Shared = 'return require(script.Parent.Parent["biff_shared@1.0.0"]["shared"])\n'
		})
	end)

	it("links a server root dependency across realms when a shared package needs it too", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("place/root@0.0.0")
			:WithDependency("Component", "biff/component@1.0.0")
			:WithServerDependency("Trove", "biff/trove@1.0.0")

		registry:Publish(PackageBuilder.new("biff/trove@1.0.0"))
		registry:Publish(PackageBuilder.new("biff/component@1.0.0"):WithDependency("Trove", "biff/trove@1.0.0"))

		local plan =
			planInstallation(resolvePackages(root:Manifest(), { }, registry:Source()).value, "place/root@0.0.0").value

		expect(plan.shared.packages["biff_trove@1.0.0"]).toBe("biff/trove@1.0.0")
		expect(plan.server.packages).toEqual({ })
		expect(plan.server.rootLinks).toEqual({
			Trove = 'return require(game.ReplicatedStorage.Packages._Plugin_Index["biff_trove@1.0.0"]["trove"])\n'
		})
	end)

	it("lets the server table win when one alias is in the shared and the server table", function()
		local identities = { "place/root@0.0.0", "biff/p@1.0.0", "biff/a@1.0.0", "biff/b@1.0.0" }
		local resolve = {
			activated = { },
			metadata = { },
			sharedDependencies = { ["biff/p@1.0.0"] = { Dup = "biff/a@1.0.0" } },
			serverDependencies = { ["biff/p@1.0.0"] = { Dup = "biff/b@1.0.0" } },
			devDependencies = { }
		}

		for _, identity in identities do
			resolve.activated[identity] = parsePackageId(identity).value
			resolve.metadata[identity] = { realm = "shared", originRealm = "shared" }
		end

		local plan = planInstallation(resolve, "place/root@0.0.0").value

		expect(plan.shared.packageLinks["biff_p@1.0.0"]).toEqual({
			Dup = 'return require(script.Parent.Parent["biff_b@1.0.0"]["b"])\n'
		})
	end)

	it("names folders as Wally does, prerelease and build metadata included", function()
		expect(packageFolderName(parsePackageId("roblox/rodux@4.0.0-rc.0").value)).toBe("roblox_rodux@4.0.0-rc.0")
		expect(packageFolderName(parsePackageId("a-b/c-d@1.2.3+build.5").value)).toBe("a-b_c-d@1.2.3+build.5")
	end)
end)
