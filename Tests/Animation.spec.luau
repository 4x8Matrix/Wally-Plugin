local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Roact = require(ReplicatedStorage.WallyPlugin.Packages.Roact)
local RoactRodux = require(ReplicatedStorage.WallyPlugin.Packages.RoactRodux)
local Rodux = require(ReplicatedStorage.WallyPlugin.Packages.Rodux)

local BusyOverlay = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.BusyOverlay)
local Interaction = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.Interaction)
local Motion = require(ReplicatedStorage.WallyPlugin.PluginInterface.Motion)
local PaletteProvider = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.PaletteProvider)
local Presence = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.Presence)
local Reducer = require(ReplicatedStorage.WallyPlugin.PluginInterface.Reducer)

local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local readReduced = Motion.ReadReduced
local mounted = {}
local selection = { kind = "result", scope = "sleitnick", name = "signal" }

local function mount(store, element): Folder
	local folder = Instance.new("Folder")
	local handle = Roact.mount(
		Roact.createElement(RoactRodux.StoreProvider, { store = store }, {
			Palette = Roact.createElement(PaletteProvider, {}, { Element = element }),
		}),
		folder
	)

	table.insert(mounted, { handle = handle, folder = folder })

	return folder
end

local function storeWith(actions: { any }): any
	local store = Rodux.Store.new(Reducer)

	for _, action in actions do
		store:dispatch(action)
	end

	return store
end

--[[
	Waits rendered frames, the ones Flipper steps its motors on; a Heartbeat can pass without one.
]]
local function frames(count: number)
	for _ = 1, count do
		RunService.RenderStepped:Wait()
	end
end

--[[
	Mounts with Roblox's reduced motion setting read as on, as a player who turned it on would see it.
]]
local function mountReduced(actions: { any }, element): Folder
	Motion.ReadReduced = function()
		return true
	end

	return mount(storeWith(actions), element)
end

local function operation(target: string)
	return {
		type = "setOperation",
		operation = { kind = "install", target = target, step = "downloading", done = 1, total = 3 },
	}
end

describe("Animation", function()
	afterEach(function()
		for _, entry in mounted do
			Roact.unmount(entry.handle)
			entry.folder:Destroy()
		end

		table.clear(mounted)
		Motion.ReadReduced = readReduced
	end)

	it("fades a hover in and out and springs a press back", function()
		local captured = {}

		mount(
			storeWith({}),
			Roact.createElement(Interaction, {
				render = function(hover, press, events)
					captured = { hover = hover, press = press, events = events }

					return Roact.createElement("Frame")
				end,
			})
		)
		captured.events[Roact.Event.MouseEnter]()
		captured.events[Roact.Event.MouseButton1Down]()
		task.wait(0.8)

		expect(captured.hover:getValue()).toBeCloseTo(1, 1)
		expect(captured.press:getValue()).toBeCloseTo(1, 1)

		captured.events[Roact.Event.MouseLeave]()
		task.wait(1)

		expect(captured.hover:getValue()).toBeCloseTo(0, 1)
		expect(captured.press:getValue()).toBeCloseTo(0, 1)
	end)

	it("never presses a disabled control", function()
		local captured = {}

		mount(
			storeWith({}),
			Roact.createElement(Interaction, {
				Disabled = true,
				render = function(hover, press, events)
					captured = { hover = hover, press = press, events = events }

					return Roact.createElement("Frame")
				end,
			})
		)
		captured.events[Roact.Event.MouseButton1Down]()
		task.wait(0.5)

		expect(captured.press:getValue()).toBe(0)
	end)

	it("keeps what left on screen, with the state it left in, until it has animated out", function()
		local closeGhost = nil
		local Probe = RoactRodux.connect(function(state)
			return { query = state.query }
		end)(function(props)
			return Roact.createElement("TextLabel", { Text = `{props.query} {props.Closing}` })
		end)
		local Host = RoactRodux.connect(function(state)
			return { store = state }
		end)(function(props)
			return Roact.createElement(Presence, {
				Present = if props.store.selection then true else false,
				State = props.store,
				Name = "Probe",
				render = function(closing: boolean, closed: () -> ())
					if closing then
						closeGhost = closed
					end

					return Roact.createElement(Probe, { Closing = closing })
				end,
			})
		end)
		local store = storeWith({
			{ type = "setQuery", query = "signal" },
			{ type = "setSelection", selection = selection },
		})
		local folder = mount(store, Roact.createElement(Host))

		expect(folder:FindFirstChild("Probe", true).Text).toBe("signal false")

		store:dispatch({ type = "setQuery", query = "trove" })
		store:dispatch({ type = "setSelection", selection = nil })
		frames(2)

		expect(folder:FindFirstChild("Probe", true)).toBe(nil)
		expect(folder:FindFirstChild("Probe closing", true).Text).toBe("signal true")

		closeGhost()
		frames(1)

		expect(folder:FindFirstChild("Probe closing", true)).toBe(nil)
	end)

	it("dims the surface its operation runs for and says the step under a spinner", function()
		local folder = mount(
			storeWith({ { type = "setSelection", selection = selection }, operation("result:sleitnick/signal") }),
			Roact.createElement(BusyOverlay)
		)

		task.wait(1)

		local busy = folder:FindFirstChild("Busy", true)

		expect(busy.Visible).toBe(true)
		expect(busy:FindFirstChild("Catch")).never.toBe(nil)
		expect(busy.BackgroundTransparency < 0.5).toBe(true)
		expect(busy:FindFirstChild("Step", true).Text).toBe("Downloading 2 of 3")
		expect(busy:FindFirstChild("Spinner", true)).never.toBe(nil)
	end)

	it("leaves other surfaces alone and fades away when the operation ends", function()
		local other = mount(
			storeWith({ { type = "setSelection", selection = selection }, operation("result:red-blox/signal") }),
			Roact.createElement(BusyOverlay)
		)
		local store =
			storeWith({ { type = "setSelection", selection = selection }, operation("result:sleitnick/signal") })
		local own = mount(store, Roact.createElement(BusyOverlay))

		task.wait(1)
		store:dispatch({ type = "setOperation", operation = nil })
		task.wait(1)

		expect(other:FindFirstChild("Busy", true).Visible).toBe(false)
		expect(own:FindFirstChild("Busy", true).Visible).toBe(false)
		expect(own:FindFirstChild("Busy", true):FindFirstChild("Catch")).toBe(nil)
	end)

	it("shows the overlay at once when reduced motion is on", function()
		local folder = mountReduced(
			{ { type = "setSelection", selection = selection }, operation("result:sleitnick/signal") },
			Roact.createElement(BusyOverlay)
		)

		frames(2)

		expect(folder:FindFirstChild("Busy", true).BackgroundTransparency).toBeCloseTo(0.2, 3)
	end)
end)
