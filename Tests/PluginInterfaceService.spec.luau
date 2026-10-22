local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Promise = require(ReplicatedStorage.WallyPlugin.Packages.Promise)
local Rodux = require(ReplicatedStorage.WallyPlugin.Packages.Rodux)
local Signal = require(ReplicatedStorage.WallyPlugin.Packages.Signal)

local PackageBuilder = require(ReplicatedStorage.Tests.Doubles.PackageBuilder)
local PluginInterfaceService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginInterfaceService)
local Reducer = require(ReplicatedStorage.WallyPlugin.PluginInterface.Reducer)

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local saved = {
	Store = PluginInterfaceService.Store,
	Registry = PluginInterfaceService.Registry,
	Packages = PluginInterfaceService.Packages,
	History = PluginInterfaceService.History,
	Selection = PluginInterfaceService.Selection,
	SearchDelay = PluginInterfaceService.SearchDelay,
}
local calls
local metadataDelays
local progressSeen
local installResult
local installed
local packages

local function state()
	return PluginInterfaceService.Store:getState()
end

local function settle()
	task.wait()
	task.wait()
end

describe("PluginInterfaceService", function()
	beforeEach(function()
		calls = {}
		metadataDelays = {}
		installResult = nil
		installed = {
			{ alias = "Trove", realm = "shared", requirement = "sleitnick/trove@^1.6.0", id = "sleitnick/trove@1.8.0" },
		}
		packages = {
			OnOperationProgress = Signal.new(),
			OnPackageAddedToIndex = Signal.new(),
			OnPackageRemovedFromIndex = Signal.new(),
			GetInstalled = function()
				return installed
			end,
			InstallAsync = function(_, name: string, realm: string, requirement: string?, alias: string?)
				table.insert(calls, `install {name} {realm} {requirement} {alias}`)
				packages.OnOperationProgress:Fire({
					operation = `Install of {name}`,
					step = "downloading",
					done = 1,
					total = 1,
				})
				progressSeen = PluginInterfaceService.Store:getState().operation

				return installResult or Promise.resolve({ added = 1, kept = 0, removed = 0, id = `{name}@2.0.3` })
			end,
			RemoveAsync = function(_, alias: string, realm: string)
				table.insert(calls, `remove {alias} {realm}`)

				return Promise.resolve({ added = 0, kept = 0, removed = 1 })
			end,
		}

		PluginInterfaceService.Store = Rodux.Store.new(Reducer)
		PluginInterfaceService.SearchDelay = 0
		PluginInterfaceService.Packages = packages
		PluginInterfaceService.Registry = {
			QueryWallyApiAsync = function(_, text: string)
				table.insert(calls, `query {text}`)

				if text == "broken" then
					return Promise.reject({ statusCode = 503, statusMessage = "Service Unavailable", body = "" })
				end

				if text == "slow" then
					return Promise.delay(0.1):andThen(function()
						return { { scope = "biff", name = "slow", description = "", versions = { "1.0.0" } } }
					end)
				end

				return Promise.resolve({
					{
						scope = "sleitnick",
						name = "signal",
						description = "Signal class",
						versions = { "2.0.3", "1.5.0" },
					},
				})
			end,
			GetPackageMetadataAsync = function(_, scope: string, name: string)
				table.insert(calls, `metadata {scope}/{name}`)

				if name == "trove" then
					return Promise.new(function(resolve)
						task.defer(resolve, { PackageBuilder.new("sleitnick/trove@1.8.0"):Manifest() })
					end)
				end

				return Promise.new(function(resolve)
					task.delay(metadataDelays[name] or 0, resolve, {
						PackageBuilder.new("sleitnick/signal@1.4.0"):Manifest(),
						PackageBuilder.new("sleitnick/signal@1.5.0"):Manifest(),
						PackageBuilder.new("sleitnick/signal@2.0.3")
							:WithDependency("Trove", "sleitnick/trove@^1.6.0")
							:Manifest(),
						PackageBuilder.new("sleitnick/signal@3.0.0-rc.1"):Manifest(),
					})
				end)
			end,
		}
		PluginInterfaceService.History = {
			OnUndo = Signal.new(),
			OnRedo = Signal.new(),
			Undo = function()
				table.insert(calls, "undo")
			end,
		}
		PluginInterfaceService.Selection = {
			Set = function(_, selection)
				table.insert(calls, `select {#selection}`)
			end,
		}
		PluginInterfaceService:OnStart()
	end)

	afterEach(function()
		PluginInterfaceService:OnStop()

		for key, value in saved do
			PluginInterfaceService[key] = value
		end
	end)

	it("searches the registry and lists what it answers", function()
		state().onSearchTextUpdated("signal")

		expect(state().query).toBe("signal")
		expect(state().search.status).toBe("searching")

		settle()

		expect(state().search.status).toBe("done")
		expect(state().search.results).toEqual({
			{ scope = "sleitnick", name = "signal", description = "Signal class", version = "2.0.3" },
		})
	end)

	it("says why a search failed", function()
		state().onSearchTextUpdated("broken")
		settle()

		expect(state().search.status).toBe("failed")
		expect(state().search.message).toBe("503 Service Unavailable")
	end)

	it("goes back to idle when the search is cleared", function()
		state().onSearchTextUpdated("signal")
		settle()
		state().onSearchTextUpdated("")

		expect(state().search).toEqual({ status = "idle", results = {} })
	end)

	it("fills the form from the registry when a result is chosen", function()
		state().onResultSelected({
			scope = "sleitnick",
			name = "signal",
			description = "Signal class",
			version = "2.0.3",
		})

		expect(state().detail.status).toBe("loading")

		settle()

		local detail = state().detail

		expect(detail.status).toBe("done")
		expect(detail.versions).toEqual({ "3.0.0-rc.1", "2.0.3", "1.5.0", "1.4.0" })
		expect(detail.latest).toBe("2.0.3")
		expect(detail.dependencies["2.0.3"]).toEqual({ "Trove = sleitnick/trove@>=1.6.0, <2.0.0" })
		expect(state().form.version).toBe("2.0.3")
		expect(state().form.alias).toBe("Signal")
		expect(state().form.realm).toBe("shared")
	end)

	it("installs what the form says, shows progress and announces the result", function()
		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		state().onInstallClicked()
		settle()

		expect(calls).toEqual(expect.arrayContaining({ "install sleitnick/signal shared ^2.0.3 Signal" }))
		expect(progressSeen.step).toBe("downloading")
		expect(progressSeen.target).toBe("result:sleitnick/signal")
		expect(state().operation).toBe(nil)
		expect(state().selection).toBe(nil)
		expect(state().notice).toEqual({ kind = "installed", message = "Installed Signal 2.0.3" })
	end)

	it("installs exactly the version chosen when a newer compatible one exists", function()
		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		state().onFormChanged({ version = "1.4.0" })
		state().onInstallClicked()
		settle()

		expect(calls).toEqual(expect.arrayContaining({ "install sleitnick/signal shared =1.4.0 Signal" }))
	end)

	it("announces a change to an older version as a roll back", function()
		installed = {
			{
				alias = "Signal",
				realm = "shared",
				requirement = "sleitnick/signal@^2.0.3",
				id = "sleitnick/signal@2.0.3",
			},
		}
		installResult = Promise.resolve({ added = 1, kept = 0, removed = 1, id = "sleitnick/signal@1.5.0" })
		PluginInterfaceService:RefreshInstalled()
		state().onInstalledSelected(state().installed[1])
		settle()
		state().onFormChanged({ version = "1.5.0" })
		state().onInstallClicked()
		settle()

		expect(state().notice.message).toBe("Rolled Signal back to 1.5.0")
	end)

	it("puts a name clash under the name field and keeps the form open", function()
		installResult = Promise.reject({
			{
				kind = "NameClash",
				message = "ReplicatedStorage.Packages.Signal already exists and was not written by the Wally plugin",
			},
			{
				kind = "DownloadFailed",
				message = "biff/x@1.0.0 could not be downloaded: the registry answered 404 Not Found",
			},
		})

		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		state().onInstallClicked()
		settle()

		expect(state().form.errors.name).toBe(
			"ReplicatedStorage.Packages.Signal already exists and was not written by the Wally plugin"
		)
		expect(state().form.errors.general).toEqual({
			"biff/x@1.0.0 could not be downloaded: the registry answered 404 Not Found",
		})
		expect(state().selection).never.toBe(nil)
		expect(state().notice.kind).toBe("failed")
	end)

	it("refuses a second install while one is running, without asking the backend", function()
		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		PluginInterfaceService.Store:dispatch({
			type = "setOperation",
			operation = { kind = "install", target = "result:red-blox/signal", step = "resolving", done = 0, total = 0 },
		})
		state().onInstallClicked()

		expect(table.find(calls, "install sleitnick/signal shared ^2.0.3 Signal")).toBe(nil)
	end)

	it("lists installed packages with their resolved version and requirement", function()
		expect(state().installed).toEqual({
			{
				alias = "Trove",
				realm = "shared",
				scope = "sleitnick",
				name = "trove",
				version = "1.8.0",
				requirement = "^1.6.0",
			},
		})
	end)

	it("removes the chosen installed package and offers Undo", function()
		state().onInstalledSelected(state().installed[1])
		settle()

		expect(state().form.version).toBe("1.8.0")

		state().onRemoveClicked()
		settle()

		expect(calls).toEqual(expect.arrayContaining({ "remove Trove shared" }))
		expect(state().notice).toEqual({ kind = "removed", message = "Removed Trove" })

		state().onUndo()

		expect(calls).toEqual(expect.arrayContaining({ "undo" }))
		expect(state().notice).toBe(nil)
	end)

	it("shows the backend's warning in the notice bar when something else takes an index", function()
		packages.OnPackageRemovedFromIndex:Fire({
			added = 0,
			kept = 0,
			removed = 3,
			lostIndex = "ReplicatedStorage.Packages._Plugin_Index",
			warning = "ReplicatedStorage.Packages._Plugin_Index was removed by something other than the Wally plugin",
		})
		settle()

		expect(state().notice).toEqual({
			kind = "lostIndex",
			message = "ReplicatedStorage.Packages._Plugin_Index was removed by something other than the Wally plugin",
		})
	end)

	it("searches at once when Enter is pressed", function()
		PluginInterfaceService.SearchDelay = 5
		state().onSearchSubmitted("signal")
		settle()

		expect(state().search.status).toBe("done")
	end)

	it("sends nothing for a search cleared before it went out", function()
		PluginInterfaceService.SearchDelay = 0.05
		state().onSearchTextUpdated("signal")
		state().onSearchTextUpdated("")
		task.wait(0.1)

		expect(table.find(calls, "query signal")).toBe(nil)
	end)

	it("drops a search answer that arrives after a newer search", function()
		state().onSearchTextUpdated("slow")
		settle()
		state().onSearchTextUpdated("signal")
		task.wait(0.2)

		expect(state().search.results[1].name).toBe("signal")
	end)

	it("drops versions that arrive after another package was chosen", function()
		metadataDelays.signal = 0.1
		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		state().onResultSelected({ scope = "sleitnick", name = "trove", description = "", version = "1.8.0" })
		task.wait(0.2)

		expect(state().detail.versions).toEqual({ "1.8.0" })
		expect(state().form.alias).toBe("Trove")
	end)

	it("names the version the install resolved to", function()
		installResult = Promise.resolve({ added = 1, kept = 0, removed = 0, id = "sleitnick/signal@2.0.5" })

		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		state().onInstallClicked()
		settle()

		expect(state().notice.message).toBe("Installed Signal 2.0.5")
	end)

	it("selects the installed root link from the notice", function()
		local rootLink = Instance.new("ModuleScript")

		rootLink.Parent = workspace
		installResult =
			Promise.resolve({ added = 1, kept = 0, removed = 0, id = "sleitnick/signal@2.0.3", rootLink = rootLink })

		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		state().onInstallClicked()
		settle()
		state().onShowInExplorer()
		rootLink:Destroy()

		expect(state().notice.rootLink).toBe(rootLink)
		expect(calls).toEqual(expect.arrayContaining({ "select 1" }))
	end)

	it("leaves a package opened during an install open when the install ends", function()
		installResult = Promise.delay(0.1):andThen(function()
			return { added = 1, kept = 0, removed = 0, id = "sleitnick/signal@2.0.3" }
		end)

		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		state().onInstallClicked()
		state().onInstalledSelected(state().installed[1])
		task.wait(0.2)

		expect(state().selection).toEqual({ kind = "installed", alias = "Trove", realm = "shared" })
		expect(state().notice.kind).toBe("installed")
	end)

	it("keeps a failed install's errors off the package opened while it ran", function()
		installResult = Promise.delay(0.1):andThen(function()
			return Promise.reject({
				{ kind = "NameClash", message = "Signal is already installed in the server realm" },
			})
		end)

		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		state().onInstallClicked()
		state().onInstalledSelected(state().installed[1])
		task.wait(0.2)

		expect(state().form.errors.name).toBe(nil)
		expect(state().operation).toBe(nil)
		expect(state().notice.kind).toBe("failed")
	end)

	it("reports an error that is not a list of problems as one problem", function()
		installResult = Promise.reject("the zip could not be read")

		state().onResultSelected({ scope = "sleitnick", name = "signal", description = "", version = "2.0.3" })
		settle()
		state().onInstallClicked()
		settle()

		expect(state().operation).toBe(nil)
		expect(state().form.errors.general).toEqual({ "the zip could not be read" })
		expect(state().notice.message).toBe("One problem stopped the install of Signal")
	end)
end)
