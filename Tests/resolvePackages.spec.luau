local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local InMemoryRegistry = require(ReplicatedStorage.Tests.Doubles.InMemoryRegistry)
local PackageBuilder = require(ReplicatedStorage.Tests.Doubles.PackageBuilder)

local resolvePackages = require(ReplicatedStorage.WallyPlugin.PluginUtilities.resolvePackages)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function shared(...: string)
	local metadata = { }

	for _, id in { ... } do
		metadata[id] = { realm = "shared", originRealm = "shared" }
	end

	return metadata
end

local function snapshot(result)
	local resolve = result.value
	local activated = { }

	for id in resolve.activated do
		table.insert(activated, id)
	end

	table.sort(activated)

	return {
		activated = activated,
		metadata = resolve.metadata,
		sharedDependencies = resolve.sharedDependencies,
		serverDependencies = resolve.serverDependencies,
		devDependencies = resolve.devDependencies
	}
end

local function resolveWith(registry, root, tryToUse)
	return resolvePackages(root:Manifest(), tryToUse or { }, registry:Source())
end

describe("resolvePackages, Wally's resolution.rs tests", function()
	it("minimal", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/minimal@0.1.0")

		expect(snapshot(resolveWith(registry, root))).toEqual({
			activated = { "biff/minimal@0.1.0" },
			metadata = shared("biff/minimal@0.1.0"),
			sharedDependencies = { },
			serverDependencies = { },
			devDependencies = { }
		})
	end)

	it("one_dependency", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/one-dependency@0.1.0"):WithDependency("Minimal", "biff/minimal@0.1.0")

		registry:Publish(PackageBuilder.new("biff/minimal@0.1.0"))
		registry:Publish(PackageBuilder.new("biff/minimal@0.2.0"))

		expect(snapshot(resolveWith(registry, root))).toEqual({
			activated = { "biff/minimal@0.1.0", "biff/one-dependency@0.1.0" },
			metadata = shared("biff/minimal@0.1.0", "biff/one-dependency@0.1.0"),
			sharedDependencies = { ["biff/one-dependency@0.1.0"] = { Minimal = "biff/minimal@0.1.0" } },
			serverDependencies = { },
			devDependencies = { }
		})
	end)

	it("transitive_dependency", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/transitive-dependency@0.1.0")
			:WithDependency("OneDependency", "biff/one-dependency@0.1.0")

		registry:Publish(PackageBuilder.new("biff/minimal@0.1.0"))
		registry:Publish(
			PackageBuilder.new("biff/one-dependency@0.1.0"):WithDependency("Minimal", "biff/minimal@0.1.0")
		)

		expect(snapshot(resolveWith(registry, root))).toEqual({
			activated = { "biff/minimal@0.1.0", "biff/one-dependency@0.1.0", "biff/transitive-dependency@0.1.0" },
			metadata = shared("biff/minimal@0.1.0", "biff/one-dependency@0.1.0", "biff/transitive-dependency@0.1.0"),
			sharedDependencies = {
				["biff/one-dependency@0.1.0"] = { Minimal = "biff/minimal@0.1.0" },
				["biff/transitive-dependency@0.1.0"] = { OneDependency = "biff/one-dependency@0.1.0" }
			},
			serverDependencies = { },
			devDependencies = { }
		})
	end)

	it("unified_dependencies", function()
		local registry = InMemoryRegistry.new()
		local root =
			PackageBuilder.new("biff/a@1.0.0"):WithDependency("B", "biff/b@1.0.0"):WithDependency("C", "biff/c@1.0.0")

		registry:Publish(PackageBuilder.new("biff/b@1.0.0"):WithDependency("D", "biff/d@1.0.0"))
		registry:Publish(PackageBuilder.new("biff/c@1.0.0"):WithDependency("D", "biff/d@1.0.0"))
		registry:Publish(PackageBuilder.new("biff/d@1.0.0"))

		expect(snapshot(resolveWith(registry, root))).toEqual({
			activated = { "biff/a@1.0.0", "biff/b@1.0.0", "biff/c@1.0.0", "biff/d@1.0.0" },
			metadata = shared("biff/a@1.0.0", "biff/b@1.0.0", "biff/c@1.0.0", "biff/d@1.0.0"),
			sharedDependencies = {
				["biff/a@1.0.0"] = { B = "biff/b@1.0.0", C = "biff/c@1.0.0" },
				["biff/b@1.0.0"] = { D = "biff/d@1.0.0" },
				["biff/c@1.0.0"] = { D = "biff/d@1.0.0" }
			},
			serverDependencies = { },
			devDependencies = { }
		})
	end)

	it("server_to_shared", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/root@1.0.0"):WithServerDependency("Server", "biff/server@1.0.0")

		registry:Publish(PackageBuilder.new("biff/shared@1.0.0"))
		registry:Publish(
			PackageBuilder.new("biff/server@1.0.0"):WithRealm("server"):WithDependency("Shared", "biff/shared@1.0.0")
		)

		expect(snapshot(resolveWith(registry, root))).toEqual({
			activated = { "biff/root@1.0.0", "biff/server@1.0.0", "biff/shared@1.0.0" },
			metadata = {
				["biff/root@1.0.0"] = { realm = "shared", originRealm = "shared" },
				["biff/server@1.0.0"] = { realm = "server", originRealm = "server" },
				["biff/shared@1.0.0"] = { realm = "shared", originRealm = "server" }
			},
			sharedDependencies = { },
			serverDependencies = {
				["biff/root@1.0.0"] = { Server = "biff/server@1.0.0" },
				["biff/server@1.0.0"] = { Shared = "biff/shared@1.0.0" }
			},
			devDependencies = { }
		})
	end)

	it("server_to_shared_and_shared_to_shared", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/root@1.0.0")
			:WithServerDependency("Server", "biff/server@1.0.0")
			:WithDependency("Shared", "biff/shared@1.0.0")

		registry:Publish(PackageBuilder.new("biff/shared@1.0.0"))
		registry:Publish(
			PackageBuilder.new("biff/server@1.0.0"):WithRealm("server"):WithDependency("Shared", "biff/shared@1.0.0")
		)

		expect(snapshot(resolveWith(registry, root))).toEqual({
			activated = { "biff/root@1.0.0", "biff/server@1.0.0", "biff/shared@1.0.0" },
			metadata = {
				["biff/root@1.0.0"] = { realm = "shared", originRealm = "shared" },
				["biff/server@1.0.0"] = { realm = "server", originRealm = "server" },
				["biff/shared@1.0.0"] = { realm = "shared", originRealm = "shared" }
			},
			sharedDependencies = {
				["biff/root@1.0.0"] = { Shared = "biff/shared@1.0.0" },
				["biff/server@1.0.0"] = { Shared = "biff/shared@1.0.0" }
			},
			serverDependencies = { ["biff/root@1.0.0"] = { Server = "biff/server@1.0.0" } },
			devDependencies = { }
		})
	end)

	it("shared_to_server", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/root@1.0.0"):WithServerDependency("Server", "biff/server@1.0.0")

		registry:Publish(PackageBuilder.new("biff/server@1.0.0"):WithRealm("server"))

		expect(snapshot(resolveWith(registry, root))).toEqual({
			activated = { "biff/root@1.0.0", "biff/server@1.0.0" },
			metadata = {
				["biff/root@1.0.0"] = { realm = "shared", originRealm = "shared" },
				["biff/server@1.0.0"] = { realm = "server", originRealm = "server" }
			},
			sharedDependencies = { },
			serverDependencies = { ["biff/root@1.0.0"] = { Server = "biff/server@1.0.0" } },
			devDependencies = { }
		})
	end)

	it("fail_server_in_shared", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/root@1.0.0"):WithDependency("Server", "biff/server@1.0.0")

		registry:Publish(PackageBuilder.new("biff/server@1.0.0"):WithRealm("server"))

		local result = resolveWith(registry, root)

		expect(result.ok).toBe(false)
		expect(result.error.kind).toBe("NoMatchingVersion")
		expect(result.error.message).toBe(
			"No packages were found that matched (Shared) biff/server@>=1.0.0, <2.0.0.\nAre you sure this is a Shared dependency?"
		)
	end)

	it("one_dependency_no_upgrade", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/one-dependency@1.0.0"):WithDependency("Minimal", "biff/minimal@1.0.0")
		local expected = {
			activated = { "biff/minimal@1.0.0", "biff/one-dependency@1.0.0" },
			metadata = shared("biff/minimal@1.0.0", "biff/one-dependency@1.0.0"),
			sharedDependencies = { ["biff/one-dependency@1.0.0"] = { Minimal = "biff/minimal@1.0.0" } },
			serverDependencies = { },
			devDependencies = { }
		}
		local tryToUse = { }

		registry:Publish(PackageBuilder.new("biff/minimal@1.0.0"))

		local first = resolveWith(registry, root)

		expect(snapshot(first)).toEqual(expected)

		for id in first.value.activated do
			tryToUse[id] = true
		end

		registry:Publish(PackageBuilder.new("biff/minimal@1.1.0"))

		expect(snapshot(resolveWith(registry, root, tryToUse))).toEqual(expected)
	end)

	it("one_dependency_yes_upgrade", function()
		local registry = InMemoryRegistry.new()
		local root = PackageBuilder.new("biff/one-dependency@1.0.0"):WithDependency("Minimal", "biff/minimal@1.0.0")
		local tryToUse = { }

		registry:Publish(PackageBuilder.new("biff/minimal@1.0.0"))

		local first = resolveWith(registry, root)

		expect(snapshot(first)).toEqual({
			activated = { "biff/minimal@1.0.0", "biff/one-dependency@1.0.0" },
			metadata = shared("biff/minimal@1.0.0", "biff/one-dependency@1.0.0"),
			sharedDependencies = { ["biff/one-dependency@1.0.0"] = { Minimal = "biff/minimal@1.0.0" } },
			serverDependencies = { },
			devDependencies = { }
		})

		for id in first.value.activated do
			if id ~= "biff/minimal@1.0.0" then
				tryToUse[id] = true
			end
		end

		registry:Publish(PackageBuilder.new("biff/minimal@1.1.0"))

		expect(snapshot(resolveWith(registry, root, tryToUse))).toEqual({
			activated = { "biff/minimal@1.1.0", "biff/one-dependency@1.0.0" },
			metadata = shared("biff/minimal@1.1.0", "biff/one-dependency@1.0.0"),
			sharedDependencies = { ["biff/one-dependency@1.0.0"] = { Minimal = "biff/minimal@1.1.0" } },
			serverDependencies = { },
			devDependencies = { }
		})
	end)
end)

describe("resolvePackages, plugin cases", function()
	it("reports a conflict with the candidates that conflicted", function()
		local registry = InMemoryRegistry.new()
		local root =
			PackageBuilder.new("biff/a@1.0.0"):WithDependency("B", "biff/b@1.0.0"):WithDependency("C", "biff/c@1.0.0")

		registry:Publish(PackageBuilder.new("biff/d@1.0.0"))
		registry:Publish(PackageBuilder.new("biff/d@1.2.0"))
		registry:Publish(PackageBuilder.new("biff/b@1.0.0"):WithDependency("D", "biff/d@=1.0.0"))
		registry:Publish(PackageBuilder.new("biff/c@1.0.0"):WithDependency("D", "biff/d@>=1.2.0, <2.0.0"))

		local result = resolveWith(registry, root)

		expect(result.error.kind).toBe("Conflict")
		expect(result.error.message).toBe(
			"All possible candidates for package biff/d@>=1.2.0, <2.0.0 (Shared) conflicted with other packages that were already installed. These packages were previously selected: biff/d@1.2.0"
		)
	end)

	it("turns a missing package into Wally's source message and passes other failures through", function()
		local root = PackageBuilder.new("biff/a@1.0.0"):WithDependency("B", "biff/b@1.0.0")
		local missing = resolvePackages(root:Manifest(), { }, {
			query = function()
				return { ok = false, error = { kind = "PackageNotFound", message = "biff/b is not in the registry" } }
			end
		})
		local unavailable = resolvePackages(root:Manifest(), { }, {
			query = function()
				return {
					ok = false,
					error = {
						kind = "RegistryUnavailable",
						message = "the registry did not answer: 503 Service Unavailable"
					}
				}
			end
		})

		expect(missing.error.kind).toBe("PackageNotFound")
		expect(missing.error.message).toBe("Failed to find a source for biff/b@>=1.0.0, <2.0.0")
		expect(unavailable.error.kind).toBe("RegistryUnavailable")
		expect(unavailable.error.message).toBe("the registry did not answer: 503 Service Unavailable")
	end)
end)
