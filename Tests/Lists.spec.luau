local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Roact = require(ReplicatedStorage.WallyPlugin.Packages.Roact)
local RoactRodux = require(ReplicatedStorage.WallyPlugin.Packages.RoactRodux)
local Rodux = require(ReplicatedStorage.WallyPlugin.Packages.Rodux)

local InstalledList = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.InstalledList)
local PaletteProvider = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.PaletteProvider)
local Reducer = require(ReplicatedStorage.WallyPlugin.PluginInterface.Reducer)
local ResultList = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.ResultList)
local Tabs = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Tabs)

local classifyWidget = require(ReplicatedStorage.WallyPlugin.PluginUtilities.classifyWidget)

local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local results = {
	{ scope = "sleitnick", name = "signal", description = "Signal class with typed connections", version = "2.0.3" },
	{ scope = "red-blox", name = "signal", description = "Fast signals with a familiar API", version = "2.0.2" },
}
local installed = {
	{
		alias = "RateLimit",
		realm = "server",
		scope = "red-blox",
		name = "ratelimit",
		version = "1.0.1",
		requirement = "^1.0.1",
	},
	{
		alias = "Promise",
		realm = "shared",
		scope = "evaera",
		name = "promise",
		version = "4.0.0",
		requirement = "^4.0.0",
	},
	{
		alias = "Trove",
		realm = "shared",
		scope = "sleitnick",
		name = "trove",
		version = "1.8.0",
		requirement = "^1.6.0",
	},
}
local mounted = {}

local function mount(state: { [string]: any }, element): Folder
	local store = Rodux.Store.new(Reducer)
	local folder = Instance.new("Folder")

	for _, payload in state do
		store:dispatch(payload)
	end

	local handle = Roact.mount(
		Roact.createElement(RoactRodux.StoreProvider, { store = store }, {
			Palette = Roact.createElement(PaletteProvider, {}, { Element = element }),
		}),
		folder
	)

	table.insert(mounted, { handle = handle, folder = folder })

	return folder
end

local function texts(root: Instance): { string }
	local found = {}

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			table.insert(found, descendant.Text)
		end
	end

	return found
end

local function searched(status: string, list: { any }, message: string?)
	return {
		query = { type = "setQuery", query = "signal" },
		search = { type = "setSearch", search = { status = status, results = list, message = message } },
	}
end

describe("Result and installed lists", function()
	afterEach(function()
		for _, entry in mounted do
			Roact.unmount(entry.handle)
			entry.folder:Destroy()
		end

		table.clear(mounted)
	end)

	it("puts name, scope and version on one line in a tiny widget", function()
		local folder =
			mount(searched("done", results), Roact.createElement(ResultList, { Layout = classifyWidget(220, 240) }))
		local row = folder:FindFirstChild("Result sleitnick/signal", true)

		expect(row:FindFirstChild("Name", true).Text).toBe("signal")
		expect(row:FindFirstChild("Scope", true).Text).toBe("sleitnick")
		expect(row:FindFirstChild("Version", true).Text).toBe("2.0.3")
		expect(row:FindFirstChild("Description", true)).toBe(nil)
	end)

	it("adds the description on a second line in a narrow widget", function()
		local folder =
			mount(searched("done", results), Roact.createElement(ResultList, { Layout = classifyWidget(320, 560) }))
		local row = folder:FindFirstChild("Result red-blox/signal", true)

		expect(row:FindFirstChild("Description", true).Text).toBe("Fast signals with a familiar API")
		expect(folder:FindFirstChild("Columns", true)).toBe(nil)
	end)

	it("lays results out as a table with column headings in a wide widget", function()
		local folder =
			mount(searched("done", results), Roact.createElement(ResultList, { Layout = classifyWidget(760, 420) }))
		local columns = folder:FindFirstChild("Columns", true)

		expect(columns).never.toBe(nil)
		expect(texts(columns)).toEqual(expect.arrayContaining({ "Package", "Description", "Latest" }))
		expect(folder:FindFirstChild("Result sleitnick/signal", true):FindFirstChild("Description", true)).never.toBe(
			nil
		)
	end)

	it("says what is happening while searching, when nothing matches and when the registry fails", function()
		local searching =
			mount(searched("searching", {}), Roact.createElement(ResultList, { Layout = classifyWidget(320, 560) }))
		local empty =
			mount(searched("done", {}), Roact.createElement(ResultList, { Layout = classifyWidget(320, 560) }))
		local failed = mount(
			searched("failed", {}, "503 Service Unavailable"),
			Roact.createElement(ResultList, { Layout = classifyWidget(320, 560) })
		)
		local idle = mount({}, Roact.createElement(ResultList, { Layout = classifyWidget(320, 560) }))

		expect(texts(searching)).toEqual(expect.arrayContaining({ 'Searching for "signal"' }))
		expect(texts(empty)).toEqual(expect.arrayContaining({ 'No packages match "signal"' }))
		expect(texts(failed)).toEqual(
			expect.arrayContaining({ "The registry didn't answer: 503 Service Unavailable", "Retry" })
		)
		expect(texts(idle)).toEqual(expect.arrayContaining({ "Search the Wally registry for a package to install" }))
	end)

	it("marks the selected result", function()
		local state = searched("done", results)

		state.selection =
			{ type = "setSelection", selection = { kind = "result", scope = "sleitnick", name = "signal" } }

		local folder = mount(state, Roact.createElement(ResultList, { Layout = classifyWidget(320, 560) }))

		expect(folder:FindFirstChild("Result sleitnick/signal", true):FindFirstChild("Selection bar", true)).never.toBe(
			nil
		)
		expect(folder:FindFirstChild("Result red-blox/signal", true):FindFirstChild("Selection bar", true)).toBe(nil)
	end)

	it("groups installed packages by realm, Shared first", function()
		local folder = mount(
			{ installed = { type = "setInstalled", installed = installed } },
			Roact.createElement(InstalledList, { Layout = classifyWidget(320, 560) })
		)
		local order = {}

		for _, name in { "Group shared", "Installed Promise", "Installed Trove", "Group server", "Installed RateLimit" } do
			table.insert(order, folder:FindFirstChild(name, true).LayoutOrder)
		end

		expect(order).toEqual({ 1, 2, 3, 4, 5 })
		expect(folder:FindFirstChild("Group shared", true):FindFirstChild("Heading", true).Text).toBe(
			"Shared, in ReplicatedStorage"
		)
		expect(folder:FindFirstChild("Installed Trove", true):FindFirstChild("Requirement", true).Text).toBe("^1.6.0")
	end)

	it("invites a search when nothing is installed", function()
		local folder = mount({}, Roact.createElement(InstalledList, { Layout = classifyWidget(320, 560) }))

		expect(texts(folder)).toEqual(
			expect.arrayContaining({ "Nothing is installed in this place yet. Search on Browse to add a package." })
		)
	end)

	it("shows the installed count on its tab and the active tab in strong text", function()
		local folder = mount({}, Roact.createElement(Tabs, { Active = "installed", InstalledCount = 3 }))

		expect(folder:FindFirstChild("Tab Installed", true):FindFirstChild("Value", true).Text).toBe("3")
		expect(folder:FindFirstChild("Tab Installed", true):FindFirstChild("Label", true).TextColor3).never.toEqual(
			folder:FindFirstChild("Tab Browse", true):FindFirstChild("Label", true).TextColor3
		)
		expect(folder:FindFirstChild("Tab indicator", true)).never.toBe(nil)
	end)
end)
