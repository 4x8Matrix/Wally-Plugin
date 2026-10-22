local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Roact = require(ReplicatedStorage.WallyPlugin.Packages.Roact)
local RoactRodux = require(ReplicatedStorage.WallyPlugin.Packages.RoactRodux)
local Rodux = require(ReplicatedStorage.WallyPlugin.Packages.Rodux)

local InstallAction = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.InstallAction)
local InstallForm = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.InstallForm)
local InstallProblems = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.InstallProblems)
local OverlayContext = require(ReplicatedStorage.WallyPlugin.PluginInterface.OverlayContext)
local Palette = require(ReplicatedStorage.WallyPlugin.PluginInterface.Palette)
local PaletteProvider = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.PaletteProvider)
local Reducer = require(ReplicatedStorage.WallyPlugin.PluginInterface.Reducer)
local VersionSelect = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.VersionSelect)

local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local palette = Palette.from(settings().Studio.Theme)
local mounted = {}
local result = { kind = "result", scope = "sleitnick", name = "signal" }
local detail = {
	status = "done",
	versions = { "2.0.3", "2.0.2", "1.5.0" },
	latest = "2.0.3",
	realms = { ["2.0.3"] = "shared", ["2.0.2"] = "shared", ["1.5.0"] = "shared" },
}

local function mount(actions: { any }, element): Folder
	local store = Rodux.Store.new(Reducer)
	local folder = Instance.new("Folder")

	for _, action in actions do
		store:dispatch(action)
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

local function selected(extra: { any }?): { any }
	local actions = {
		{ type = "setSelection", selection = result },
		{ type = "setDetail", detail = detail },
		{ type = "setForm", form = { version = "2.0.3", realm = "shared", alias = "Signal" } },
	}

	for _, action in extra or {} do
		table.insert(actions, action)
	end

	return actions
end

describe("Install form", function()
	afterEach(function()
		for _, entry in mounted do
			Roact.unmount(entry.handle)
			entry.folder:Destroy()
		end

		table.clear(mounted)
	end)

	it("puts each error under the field it concerns", function()
		local folder = mount(
			selected({
				{ type = "setForm", form = { errors = { name = "taken by another module", version = "none match" } } },
			}),
			Roact.createElement(InstallForm, { Layout = "pair" })
		)
		local nameError = folder:FindFirstChild("Field Name", true):FindFirstChild("Error", true)

		expect(nameError:FindFirstChild("Message", true).Text).toBe("taken by another module")
		expect(
			folder
				:FindFirstChild("Field Version", true)
				:FindFirstChild("Error", true)
				:FindFirstChild("Message", true).Text
		).toBe("none match")
		expect(folder:FindFirstChild("Field Realm", true):FindFirstChild("Error", true)).toBe(nil)
	end)

	it("shows nothing for general problems when there are none", function()
		local folder = mount(selected(), Roact.createElement(InstallProblems))

		expect(#folder:GetChildren()).toBe(0)
	end)

	it("marks every error with the error icon on a tinted block", function()
		local folder = mount(
			selected({ { type = "setForm", form = { errors = { name = "taken by another module" } } } }),
			Roact.createElement(InstallForm, { Layout = "pair" })
		)
		local block = folder:FindFirstChild("Field Name", true):FindFirstChild("Error", true)

		task.wait(1)

		expect(block.BackgroundColor3).toEqual(palette.error)
		expect(block.BackgroundTransparency).toBeCloseTo(Palette.WashTransparency, 5)
		expect(block:FindFirstChild("Icon", true).Image).toBe("rbxasset://textures/StudioSharedUI/alert_error.png")
	end)

	it("shows why the versions could not be read in place of the picker", function()
		local folder = mount(
			selected({
				{
					type = "setDetail",
					detail = { status = "failed", versions = {}, realms = {}, message = "503 Service Unavailable" },
				},
			}),
			Roact.createElement(InstallForm, { Layout = "pair" })
		)
		local field = folder:FindFirstChild("Field Version", true)

		expect(field:FindFirstChild("Options", true)).toBe(nil)
		expect(field:FindFirstChild("Message", true).Text).toBe("Couldn't read the versions: 503 Service Unavailable")
		expect(field:FindFirstChild("Icon", true)).never.toBe(nil)
	end)

	it("lists general problems one block each", function()
		local folder = mount(
			selected({
				{
					type = "setForm",
					form = { errors = { general = { "the registry did not answer", "a package could not be built" } } },
				},
			}),
			Roact.createElement(InstallProblems)
		)
		local problems = folder:FindFirstChild("Element")

		expect(problems:FindFirstChild("Problem 1"):FindFirstChild("Message", true).Text).toBe(
			"the registry did not answer"
		)
		expect(problems:FindFirstChild("Problem 2"):FindFirstChild("Message", true).Text).toBe(
			"a package could not be built"
		)
		expect(problems:FindFirstChild("Problem 1"):FindFirstChild("Icon", true)).never.toBe(nil)
	end)

	it("names the version and the alias on the button", function()
		local folder = mount(selected(), Roact.createElement(InstallAction))

		expect(folder:FindFirstChild("Install button", true):FindFirstChild("Label", true).Text).toBe(
			"Install Signal 2.0.3"
		)
	end)

	it("shows progress on the button while its own install runs", function()
		local folder = mount(
			selected({
				{
					type = "setOperation",
					operation = {
						kind = "install",
						target = "result:sleitnick/signal",
						step = "downloading",
						done = 1,
						total = 2,
					},
				},
			}),
			Roact.createElement(InstallAction)
		)
		local button = folder:FindFirstChild("Install button", true)

		expect(button:FindFirstChild("Label", true).Text).toBe("Downloading 2 of 2")
		expect(button:FindFirstChild("Fill", true).Visible).toBe(true)
	end)

	it("refuses while another install runs and says so", function()
		local folder = mount(
			selected({
				{
					type = "setOperation",
					operation = {
						kind = "install",
						target = "result:red-blox/signal",
						step = "resolving",
						done = 0,
						total = 0,
					},
				},
			}),
			Roact.createElement(InstallAction)
		)
		local button = folder:FindFirstChild("Install button", true)

		expect(button:FindFirstChild("Label", true).Text).toBe("Another install is running")
		expect(button:FindFirstChild("Face").BackgroundColor3).toEqual(palette.track)
	end)

	it("keeps Shared off for a server-only package", function()
		local folder = mount(
			selected({
				{
					type = "setDetail",
					detail = {
						status = "done",
						versions = { "1.0.0" },
						latest = "1.0.0",
						realms = { ["1.0.0"] = "server" },
					},
				},
				{ type = "setForm", form = { version = "1.0.0", realm = "server" } },
			}),
			Roact.createElement(InstallForm, { Layout = "stacked" })
		)

		expect(folder:FindFirstChild("Realm Shared", true).Active).toBe(false)
		expect(folder:FindFirstChild("Realm Server", true).Active).toBe(true)
	end)

	it("lists versions in the order the service sorted them, with the latest marked", function()
		local folder = mount(
			{},
			Roact.createElement(
				VersionSelect,
				{ Versions = { "3.0.0-rc.1", "1.5.0", "2.0.3" }, Latest = "2.0.3", Value = "2.0.3", Open = true }
			)
		)
		local options = folder:FindFirstChild("Options", true)

		expect(options:FindFirstChild("Version 3.0.0-rc.1", true).LayoutOrder).toBe(1)
		expect(options:FindFirstChild("Version 1.5.0", true).LayoutOrder).toBe(2)
		expect(options:FindFirstChild("Version 2.0.3", true).LayoutOrder).toBe(3)
		expect(options:FindFirstChild("Version 2.0.3", true):FindFirstChild("Tag", true).Text).toBe("latest")
	end)

	it("offers an update and a removal for an installed package", function()
		local installedSelection = {
			{
				type = "setInstalled",
				installed = {
					{
						alias = "Signal",
						realm = "shared",
						scope = "sleitnick",
						name = "signal",
						version = "2.0.2",
						requirement = "^2.0.2",
					},
				},
			},
			{ type = "setSelection", selection = { kind = "installed", alias = "Signal", realm = "shared" } },
			{ type = "setDetail", detail = detail },
			{ type = "setForm", form = { version = "2.0.3", realm = "shared", alias = "Signal" } },
		}
		local upToDate = table.clone(installedSelection)

		table.insert(upToDate, { type = "setForm", form = { version = "2.0.2" } })

		local update = mount(installedSelection, Roact.createElement(InstallAction))
		local same = mount(upToDate, Roact.createElement(InstallAction))

		expect(update:FindFirstChild("Install button", true):FindFirstChild("Label", true).Text).toBe("Update to 2.0.3")
		expect(update:FindFirstChild("Remove", true).Text).toBe("Remove Signal")
		expect(same:FindFirstChild("Install button", true):FindFirstChild("Label", true).Text).toBe(
			"2.0.2 is installed"
		)
	end)

	it("calls going to an older version a roll back", function()
		local folder = mount({
			{
				type = "setInstalled",
				installed = {
					{
						alias = "Signal",
						realm = "shared",
						scope = "sleitnick",
						name = "signal",
						version = "2.0.3",
						requirement = "^2.0.3",
					},
				},
			},
			{ type = "setSelection", selection = { kind = "installed", alias = "Signal", realm = "shared" } },
			{ type = "setDetail", detail = detail },
			{ type = "setForm", form = { version = "1.5.0", realm = "shared", alias = "Signal" } },
		}, Roact.createElement(InstallAction))

		expect(folder:FindFirstChild("Install button", true):FindFirstChild("Label", true).Text).toBe(
			"Roll back to 1.5.0"
		)
	end)

	it("opens the version list over a surface that offers room for it", function()
		local target = Instance.new("Frame")
		local folder = mount(
			{},
			Roact.createElement(OverlayContext.Provider, { value = target }, {
				Select = Roact.createElement(
					VersionSelect,
					{ Versions = { "2.0.3", "2.0.2", "1.5.0" }, Latest = "2.0.3", Value = "2.0.3", Open = true }
				),
			})
		)
		local picker = target:FindFirstChild("Version picker")

		expect(picker).never.toBe(nil)
		expect(picker:FindFirstChild("Version 2.0.2", true)).never.toBe(nil)
		expect(picker:FindFirstChild("Close", true)).never.toBe(nil)
		expect(folder:FindFirstChild("Options", true)).toBe(nil)
		target:Destroy()
	end)

	it("tags the installed version in the version list", function()
		local folder = mount(
			{},
			Roact.createElement(VersionSelect, {
				Versions = { "2.0.3", "2.0.2", "1.5.0" },
				Latest = "2.0.3",
				Installed = "2.0.2",
				Value = "2.0.2",
				Open = true,
			})
		)
		local options = folder:FindFirstChild("Options", true)

		expect(options:FindFirstChild("Version 2.0.2", true):FindFirstChild("Tag", true).Text).toBe("installed")
		expect(options:FindFirstChild("Version 2.0.3", true):FindFirstChild("Tag", true).Text).toBe("latest")
	end)

	it("says an installed package has gone instead of offering a button that does nothing", function()
		local folder = mount({
			{ type = "setSelection", selection = { kind = "installed", alias = "Signal", realm = "shared" } },
			{ type = "setDetail", detail = detail },
			{ type = "setForm", form = { version = "2.0.3", realm = "shared", alias = "Signal" } },
		}, Roact.createElement(InstallAction))
		local button = folder:FindFirstChild("Install button", true)

		expect(button:FindFirstChild("Label", true).Text).toBe("No longer installed")
		expect(button:FindFirstChild("Face").BackgroundColor3).toEqual(palette.track)
	end)
end)
