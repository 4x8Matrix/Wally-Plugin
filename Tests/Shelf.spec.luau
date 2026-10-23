local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Roact = require(ReplicatedStorage.WallyPlugin.Packages.Roact)
local RoactRodux = require(ReplicatedStorage.WallyPlugin.Packages.RoactRodux)
local Rodux = require(ReplicatedStorage.WallyPlugin.Packages.Rodux)

local Motion = require(ReplicatedStorage.WallyPlugin.PluginInterface.Motion)
local PaletteProvider = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.PaletteProvider)
local Reducer = require(ReplicatedStorage.WallyPlugin.PluginInterface.Reducer)
local Shelf = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Shelf)

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local surfaces = { "Sheet", "Inline options", "Full panel", "Side panel", "Strip panel" }
local frames = {
	{ 320, 560, "Sheet" },
	{ 260, 1200, "Inline options" },
	{ 220, 240, "Full panel" },
	{ 300, 300, "Full panel" },
	{ 480, 480, "Sheet" },
	{ 720, 720, "Side panel" },
	{ 760, 420, "Side panel" },
	{ 1100, 800, "Side panel" },
	{ 1280, 200, "Strip panel" },
	{ 1500, 160, "Strip panel" },
}
local mounted = {}
local readReduced = Motion.ReadReduced
local problems = {
	type = "setForm",
	form = {
		errors = {
			general = {
				"biff/one@1.0.0 could not be downloaded: the registry answered 404 Not Found",
				"biff/two@1.0.0 could not be downloaded: the registry answered 404 Not Found",
				"biff/three@1.0.0 could not be downloaded: the registry answered 404 Not Found",
				"biff/four@1.0.0 could not be downloaded: the registry answered 404 Not Found",
				"biff/five@1.0.0 could not be downloaded: the registry answered 404 Not Found",
				"biff/six@1.0.0 could not be downloaded: the registry answered 404 Not Found",
			},
		},
	},
}

local function seeded(selected: boolean): { any }
	local actions = {
		{ type = "setQuery", query = "signal" },
		{
			type = "setSearch",
			search = {
				status = "done",
				results = {
					{
						scope = "sleitnick",
						name = "signal",
						description = "Signal class with typed connections",
						version = "2.0.3",
					},
					{
						scope = "red-blox",
						name = "signal",
						description = "Fast signals with a familiar API",
						version = "2.0.2",
					},
				},
			},
		},
		{
			type = "setInstalled",
			installed = {
				{
					alias = "Trove",
					realm = "shared",
					scope = "sleitnick",
					name = "trove",
					version = "1.8.0",
					requirement = "^1.6.0",
				},
			},
		},
	}

	if selected then
		table.insert(
			actions,
			{ type = "setSelection", selection = { kind = "result", scope = "sleitnick", name = "signal" } }
		)
		table.insert(actions, {
			type = "setDetail",
			detail = {
				status = "done",
				versions = { "2.0.3", "2.0.2" },
				latest = "2.0.3",
				realms = { ["2.0.3"] = "shared", ["2.0.2"] = "shared" },
			},
		})
		table.insert(actions, { type = "setForm", form = { version = "2.0.3", realm = "shared", alias = "Signal" } })
	end

	return actions
end

local function mount(actions: { any }, width: number, height: number): Folder
	local store = Rodux.Store.new(Reducer)
	local folder = Instance.new("Folder")

	for _, action in actions do
		store:dispatch(action)
	end

	local handle = Roact.mount(
		Roact.createElement(RoactRodux.StoreProvider, { store = store }, {
			Palette = Roact.createElement(PaletteProvider, {}, {
				Shelf = Roact.createElement(Shelf, { LayoutSize = Vector2.new(width, height) }),
			}),
		}),
		folder
	)

	table.insert(mounted, { handle = handle, folder = folder })

	return folder
end

--[[
	Mounts the Shelf into a frame on screen, so layout runs and the surfaces can measure what they hold.
]]
local function mountOnScreen(actions: { any }, width: number, height: number): (Frame, any)
	local store = Rodux.Store.new(Reducer)
	local screen = Instance.new("ScreenGui")
	local frame = Instance.new("Frame")

	for _, action in actions do
		store:dispatch(action)
	end

	frame.Size = UDim2.fromOffset(width, height)
	frame.Parent = screen
	screen.Parent = StarterGui

	local handle = Roact.mount(
		Roact.createElement(RoactRodux.StoreProvider, { store = store }, {
			Palette = Roact.createElement(PaletteProvider, {}, {
				Shelf = Roact.createElement(Shelf, { LayoutSize = Vector2.new(width, height) }),
			}),
		}),
		frame
	)

	table.insert(mounted, { handle = handle, folder = screen })

	for _ = 1, 4 do
		task.wait()
	end

	return frame, store
end

local function withProblems(): { any }
	local actions = seeded(true)

	table.insert(actions, problems)

	return actions
end

--[[
	The first instance named `name`, or named `name` and then what it is open on, as the options opened in place are.
]]
local function findSurface(root: Instance, name: string): Instance?
	for _, descendant in root:GetDescendants() do
		if descendant.Name == name or string.sub(descendant.Name, 1, #name + 1) == `{name} ` then
			return descendant
		end
	end

	return
end

--[[
	The height of the install options opened in place, or of the one-line strip's row.
]]
local function measureSurface(root: Instance): number
	local surface = findSurface(root, "Inline options") or findSurface(root, "Strip panel"):FindFirstChild("Row", true)

	return surface.AbsoluteSize.Y
end

--[[
	Waits rendered frames, the ones Flipper steps its motors on.
]]
local function renderFrames(count: number)
	for _ = 1, count do
		RunService.RenderStepped:Wait()
	end
end

--[[
	The installed list the seeded store holds, so a spec can take it away and give it back.
]]
local function seededInstalled(): { any }
	for _, action in seeded(false) do
		if action.type == "setInstalled" then
			return action.installed
		end
	end

	return {}
end

describe("Shelf", function()
	beforeEach(function()
		Motion.ReadReduced = function()
			return false
		end
	end)

	afterEach(function()
		for _, entry in mounted do
			Roact.unmount(entry.handle)
			entry.folder:Destroy()
		end

		table.clear(mounted)
		Motion.ReadReduced = readReduced
	end)

	for _, frame in frames do
		local width, height, expected = table.unpack(frame)

		it(`opens the install options as the {expected} at {width} x {height}`, function()
			local folder = mount(seeded(true), width, height)

			for _, surface in surfaces do
				if surface == expected then
					expect(findSurface(folder, surface)).never.toBe(nil)
				else
					expect(findSurface(folder, surface)).toBe(nil)
				end
			end

			expect(findSurface(folder, expected):FindFirstChild("Install button", true)).never.toBe(nil)
		end)
	end

	it("shows no install surface over the list until something is selected", function()
		for _, frame in { { 320, 560 }, { 220, 240 }, { 260, 1200 } } do
			local folder = mount(seeded(false), frame[1], frame[2])

			for _, surface in surfaces do
				expect(findSurface(folder, surface)).toBe(nil)
			end
		end
	end)

	it("keeps the side and strip panels open with an invitation when nothing is selected", function()
		local side = mount(seeded(false), 760, 420)
		local strip = mount(seeded(false), 1280, 200)

		expect(side:FindFirstChild("Side panel", true):FindFirstChild("Empty", true).Text).toBe(
			"Pick a package to see its versions and install it"
		)
		expect(strip:FindFirstChild("Strip panel", true):FindFirstChild("Empty", true)).never.toBe(nil)
	end)

	it("folds Installed into a section under the results in a very tall widget", function()
		local folder = mount(seeded(false), 260, 1200)

		expect(folder:FindFirstChild("Tab Browse", true)).toBe(nil)
		expect(folder:FindFirstChild("Installed section", true)).never.toBe(nil)
		expect(folder:FindFirstChild("Installed Trove", true)).never.toBe(nil)
	end)

	it("puts tabs and search in one bar in a strip", function()
		local folder = mount(seeded(false), 1280, 200)
		local bar = folder:FindFirstChild("Top bar", true)

		expect(bar:FindFirstChild("Tab Browse", true)).never.toBe(nil)
		expect(bar:FindFirstChild("Search", true)).never.toBe(nil)
	end)

	it("keeps rows readable beside a strip panel in a narrow strip", function()
		local folder = mount(seeded(false), 680, 200)
		local row = folder:FindFirstChild("Result sleitnick/signal", true)

		expect(row:FindFirstChild("Names", true)).toBe(nil)
		expect(row:FindFirstChild("Description", true)).toBe(nil)
		expect(row.Content:FindFirstChild("Line")).never.toBe(nil)
	end)

	it("searches as soon as Enter is pressed in the search field", function()
		local frame, store = mountOnScreen(seeded(false), 320, 560)
		local submitted = nil
		local input = frame:FindFirstChild("Search", true):FindFirstChildWhichIsA("TextBox", true)

		store:dispatch({
			type = "setCallbacks",
			callbacks = {
				onSearchSubmitted = function(text: string)
					submitted = text
				end,
			},
		})
		task.wait()
		input:CaptureFocus()
		task.wait()
		input:ReleaseFocus(true)
		task.wait()

		expect(submitted).toBe("signal")
	end)

	it("lets the action follow the last field while everything fits", function()
		for _, frame in { (mountOnScreen(seeded(true), 320, 700)), (mountOnScreen(seeded(true), 1100, 800)) } do
			local scroll = frame:FindFirstChild("Scroll", true)
			local button = frame:FindFirstChild("Install button", true)

			expect(scroll.AbsoluteSize.Y).toBe(scroll.Content.AbsoluteSize.Y)
			expect(button.AbsolutePosition.Y - (scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y) < 16).toBe(true)
		end
	end)

	it("pins the action at the bottom and scrolls the fields once they overflow", function()
		for _, frame in
			{
				(mountOnScreen(withProblems(), 320, 400)),
				(mountOnScreen(withProblems(), 760, 420)),
				(mountOnScreen(withProblems(), 300, 300)),
			}
		do
			local scroll = frame:FindFirstChild("Scroll", true)
			local button = frame:FindFirstChild("Install button", true)
			local frameBottom = frame.AbsolutePosition.Y + frame.AbsoluteSize.Y

			expect(scroll.AbsoluteSize.Y < scroll.Content.AbsoluteSize.Y).toBe(true)
			expect(button.AbsolutePosition.Y + button.AbsoluteSize.Y <= frameBottom).toBe(true)
			expect(frameBottom - (button.AbsolutePosition.Y + button.AbsoluteSize.Y) < 40).toBe(true)
		end
	end)

	it("dims the open surface under a spinner while its install runs", function()
		for _, size in
			{
				Vector2.new(320, 560),
				Vector2.new(220, 240),
				Vector2.new(760, 420),
				Vector2.new(1280, 200),
				Vector2.new(260, 1200),
			}
		do
			local actions = seeded(true)

			table.insert(actions, {
				type = "setOperation",
				operation = {
					kind = "install",
					target = "result:sleitnick/signal",
					step = "downloading",
					done = 0,
					total = 2,
				},
			})

			local frame = mountOnScreen(actions, size.X, size.Y)

			task.wait(1)

			local busy = frame:FindFirstChild("Busy", true)

			expect(busy).never.toBe(nil)
			expect(busy.Visible).toBe(true)
			expect(busy:FindFirstChild("Step", true).Text).toBe("Downloading 1 of 2")
			expect(busy:IsDescendantOf(frame:FindFirstChild("Install button", true).Parent)).toBe(false)
		end
	end, 15000)

	it("keeps the in-place options and the one-line strip their own height while an install runs", function()
		local operation = {
			type = "setOperation",
			operation = {
				kind = "install",
				target = "result:sleitnick/signal",
				step = "downloading",
				done = 0,
				total = 2,
			},
		}

		for _, size in { Vector2.new(370, 1150), Vector2.new(1500, 160) } do
			local busyFromTheStart = seeded(true)
			local frame, store = mountOnScreen(seeded(true), size.X, size.Y)

			table.insert(busyFromTheStart, operation)
			task.wait(1)

			local idle = measureSurface(frame)

			store:dispatch(operation)

			local opened = mountOnScreen(busyFromTheStart, size.X, size.Y)

			task.wait(1)

			expect(frame:FindFirstChild("Busy", true).Visible).toBe(true)
			expect(measureSurface(frame)).toBe(idle)
			expect(measureSurface(opened)).toBe(idle)
		end
	end, 15000)

	it("slides the sheet away with its last content when it closes", function()
		local frame, store = mountOnScreen(seeded(true), 320, 560)

		task.wait(1)

		local before = frame:FindFirstChild("Sheet", true).AbsolutePosition.Y

		store:dispatch({ type = "setSelection", selection = nil })
		renderFrames(2)

		local sheet = frame:FindFirstChild("Sheet", true)

		expect(sheet).never.toBe(nil)
		expect(sheet:FindFirstChild("Title", true).Text).toBe("Signal")
		expect(sheet.AbsolutePosition.Y > before).toBe(true)

		task.wait(1.5)

		expect(frame:FindFirstChild("Sheet", true)).toBe(nil)
	end, 10000)

	it("pushes the full panel back out over the list when it closes", function()
		local frame, store = mountOnScreen(seeded(true), 220, 240)

		task.wait(1)
		store:dispatch({ type = "setSelection", selection = nil })
		renderFrames(2)

		local leaving = frame:FindFirstChild("Full panel closing", true)

		expect(leaving).never.toBe(nil)
		expect(leaving.AbsolutePosition.X > frame.AbsolutePosition.X).toBe(true)
		expect(frame:FindFirstChild("Result sleitnick/signal", true)).never.toBe(nil)

		task.wait(1.5)

		expect(frame:FindFirstChild("Full panel closing", true)).toBe(nil)
	end, 10000)

	it("folds the in-place options shut", function()
		local frame, store = mountOnScreen(seeded(true), 260, 1200)

		task.wait(1)

		local open = findSurface(frame, "Inline options").AbsoluteSize.Y

		store:dispatch({ type = "setSelection", selection = nil })
		renderFrames(2)

		local closing = findSurface(frame, "Closing inline options")

		expect(closing).never.toBe(nil)
		expect(closing.AbsoluteSize.Y < open).toBe(true)

		task.wait(1.5)

		expect(findSurface(frame, "Closing inline options")).toBe(nil)
	end, 10000)

	it("slides a dismissed notice away", function()
		local actions = seeded(false)

		table.insert(actions, {
			type = "setNotice",
			notice = { kind = "installed", message = "Installed Signal 2.0.3" },
		})

		local frame, store = mountOnScreen(actions, 320, 560)

		task.wait(1)

		local full = frame:FindFirstChild("Edge", true).Parent.AbsoluteSize.Y

		store:dispatch({ type = "setNotice", notice = nil })
		renderFrames(2)

		local edge = frame:FindFirstChild("Edge", true)

		expect(edge).never.toBe(nil)
		expect(edge.Parent.AbsoluteSize.Y < full).toBe(true)

		task.wait(1.5)

		expect(frame:FindFirstChild("Edge", true)).toBe(nil)
	end, 10000)

	it("floats the version list over the full and strip panels, which have no room to open it in place", function()
		for _, size in
			{
				{ 220, 240, "Full panel" },
				{ 400, 300, "Full panel" },
				{ 1280, 200, "Strip panel" },
				{ 1500, 160, "Strip panel" },
			}
		do
			local frame = mountOnScreen(seeded(true), size[1], size[2])

			expect(frame:FindFirstChild(size[3], true):FindFirstChild("Floating layer", true)).never.toBe(nil)
		end

		for _, size in { { 400, 600 }, { 1000, 600 } } do
			local frame = mountOnScreen(seeded(true), size[1], size[2])

			expect(frame:FindFirstChild("Floating layer", true)).toBe(nil)
		end
	end, 10000)

	it("crossfades the strip panel when another package is chosen", function()
		local frame, store = mountOnScreen(seeded(true), 1280, 200)

		task.wait(1)

		local cover = frame:FindFirstChild("Strip panel", true):FindFirstChild("Cover", true)

		store:dispatch({
			type = "setSelection",
			selection = { kind = "result", scope = "red-blox", name = "signal" },
		})
		store:flush()

		expect(cover.Visible).toBe(true)
		expect(cover.BackgroundTransparency).toBe(0)

		task.wait(1)

		expect(cover.Visible).toBe(false)
	end, 10000)

	it("forgets a closing copy whose row has gone", function()
		local actions = seeded(false)

		table.insert(actions, {
			type = "setSelection",
			selection = { kind = "installed", alias = "Trove", realm = "shared" },
		})

		local frame, store = mountOnScreen(actions, 260, 1200)

		task.wait(1)
		store:dispatch({ type = "setSelection", selection = nil })
		store:dispatch({ type = "setInstalled", installed = {} })
		task.wait(1)
		store:dispatch({ type = "setInstalled", installed = seededInstalled() })
		renderFrames(3)

		expect(findSurface(frame, "Closing inline options")).toBe(nil)
	end, 10000)

	it("unfolds the newly chosen package's options when switching in place", function()
		local frame, store = mountOnScreen(seeded(true), 260, 1200)
		local heights = {}
		local closing = nil

		task.wait(1)
		store:dispatch({
			type = "setSelection",
			selection = { kind = "result", scope = "red-blox", name = "signal" },
		})

		for _ = 1, 15 do
			RunService.RenderStepped:Wait()

			local opening = frame:FindFirstChild("Inline options result:red-blox/signal", true)
			local leaving = findSurface(frame, "Closing inline options")

			if opening then
				table.insert(heights, opening.AbsoluteSize.Y)
			end

			closing = closing or (leaving and leaving.Name)
		end

		expect(heights[1] < heights[#heights]).toBe(true)
		expect(closing).toBe("Closing inline options result:sleitnick/signal")
	end, 10000)

	it("closes each package's options as itself when they change quickly", function()
		local frame, store = mountOnScreen(seeded(true), 260, 1200)

		task.wait(1)
		store:dispatch({
			type = "setSelection",
			selection = { kind = "result", scope = "red-blox", name = "signal" },
		})
		renderFrames(2)
		store:dispatch({ type = "setSelection", selection = nil })
		renderFrames(2)

		expect(findSurface(frame, "Closing inline options").Name).toBe("Closing inline options result:red-blox/signal")
	end, 10000)

	it("keeps a closing sheet's busy wash steady as it slides away", function()
		local actions = seeded(true)

		table.insert(actions, {
			type = "setOperation",
			operation = { kind = "install", target = "result:sleitnick/signal", step = "writing", done = 1, total = 1 },
		})

		local frame, store = mountOnScreen(actions, 320, 560)

		task.wait(1)
		store:dispatch({ type = "setOperation", operation = nil })
		store:dispatch({ type = "setSelection", selection = nil })
		renderFrames(2)

		expect(frame:FindFirstChild("Busy", true).BackgroundTransparency < 0.3).toBe(true)
	end, 10000)

	it("shows the results at once when the list mounts, without replaying their fade", function()
		local frame = mountOnScreen(seeded(false), 320, 560)
		local name = frame:FindFirstChild("Result sleitnick/signal", true):FindFirstChild("Name", true)

		expect(name.TextTransparency).toBe(0)
	end)

	it("fades a new set of results in, never a later row ahead of an earlier one", function()
		local frame, store = mountOnScreen(seeded(false), 320, 560)
		local results = {
			{ scope = "biff", name = "first", description = "", version = "1.0.0" },
			{ scope = "biff", name = "second", description = "", version = "1.0.0" },
		}
		local faded = false
		local ahead = false

		store:dispatch({ type = "setSearch", search = { status = "done", results = results } })

		for _ = 1, 30 do
			RunService.RenderStepped:Wait()

			local first = frame:FindFirstChild("Result biff/first", true)
			local second = frame:FindFirstChild("Result biff/second", true)

			if first and second then
				local firstShown = first:FindFirstChild("Name", true).TextTransparency
				local secondShown = second:FindFirstChild("Name", true).TextTransparency

				faded = faded or secondShown > 0
				ahead = ahead or secondShown < firstShown
			end
		end

		task.wait(1)

		expect(faded).toBe(true)
		expect(ahead).toBe(false)
		expect(frame:FindFirstChild("Result biff/second", true):FindFirstChild("Name", true).TextTransparency).toBe(0)
	end, 10000)

	it("keeps every row's height while new results rise into place", function()
		local frame, store = mountOnScreen(seeded(false), 320, 560)
		local results = {
			{ scope = "biff", name = "first", description = "One", version = "1.0.0" },
			{ scope = "biff", name = "second", description = "Two", version = "1.0.0" },
			{ scope = "biff", name = "third", description = "Three", version = "1.0.0" },
		}
		local heights = {}

		store:dispatch({ type = "setSearch", search = { status = "done", results = results } })

		for _ = 1, 20 do
			RunService.RenderStepped:Wait()

			local row = frame:FindFirstChild("Result biff/third", true)

			if row then
				heights[row.AbsoluteSize.Y] = true
			end
		end

		local seen = 0

		for _ in heights do
			seen += 1
		end

		expect(seen).toBe(1)
	end, 10000)

	it("pops the installed count without resizing its tab", function()
		local frame, store = mountOnScreen(seeded(false), 320, 560)
		local tab = frame:FindFirstChild("Tab Installed", true)
		local width = tab.AbsoluteSize.X
		local widest = width
		local installed = table.clone(seededInstalled())

		table.insert(installed, {
			alias = "Signal",
			realm = "shared",
			scope = "sleitnick",
			name = "signal",
			version = "2.0.3",
			requirement = "^2.0.3",
		})
		store:dispatch({ type = "setInstalled", installed = installed })

		for _ = 1, 12 do
			RunService.RenderStepped:Wait()
			widest = math.max(widest, tab.AbsoluteSize.X)
		end

		expect(widest).toBe(width)
	end, 10000)

	it("takes no clicks on a notice that is sliding away", function()
		local actions = seeded(false)

		table.insert(actions, {
			type = "setNotice",
			notice = { kind = "installed", message = "Installed Signal 2.0.3" },
		})

		local frame, store = mountOnScreen(actions, 320, 560)

		task.wait(1)
		store:dispatch({ type = "setNotice", notice = nil })
		renderFrames(2)

		expect(frame:FindFirstChild("Edge", true).Parent:FindFirstChild("Shield")).never.toBe(nil)
	end, 10000)

	it("draws nothing through a CanvasGroup, which blurs and rebuilds its texture as it resizes", function()
		for _, size in { Vector2.new(260, 1200), Vector2.new(760, 420), Vector2.new(1280, 200), Vector2.new(320, 560) } do
			local folder = mount(seeded(true), size.X, size.Y)

			expect(folder:FindFirstChildWhichIsA("CanvasGroup", true)).toBe(nil)
		end
	end)

	it("lets the in-place options size themselves once they have opened", function()
		local frame = mountOnScreen(seeded(true), 260, 1200)

		task.wait(1)

		expect(findSurface(frame, "Inline options").AutomaticSize).toBe(Enum.AutomaticSize.Y)
	end, 10000)

	it("says the registry found 100 or more when it hands back its most", function()
		local actions = seeded(false)
		local results = {}

		for index = 1, 100 do
			table.insert(results, { scope = "biff", name = `package{index}`, description = "", version = "1.0.0" })
		end

		table.insert(actions, { type = "setSearch", search = { status = "done", results = results } })

		local folder = mount(actions, 320, 560)

		expect(folder:FindFirstChild("Search", true):FindFirstChild("Hint", true).Text).toBe("100+ found")
	end)

	it("keeps the notice bar's height while its notice rises into view", function()
		local actions = seeded(false)

		table.insert(actions, {
			type = "setNotice",
			notice = { kind = "installed", message = "Installed Signal 2.0.3" },
		})

		local frame = mountOnScreen(actions, 320, 560)
		local bar = frame:FindFirstChild("Edge", true).Parent
		local rising = bar.AbsoluteSize.Y

		for _ = 1, 40 do
			task.wait()
		end

		expect(rising).toBe(bar.AbsoluteSize.Y)
		expect(
			bar:FindFirstChild("Message", true).AbsolutePosition.Y + 16 <= bar.AbsolutePosition.Y + bar.AbsoluteSize.Y
		).toBe(true)
	end)

	it("keeps a strip's general problems in view after a failed install", function()
		for _, size in { Vector2.new(1280, 200), Vector2.new(1500, 160) } do
			local actions = withProblems()

			table.insert(
				actions,
				{ type = "setNotice", notice = { kind = "failed", message = "6 problems stopped the install" } }
			)

			local frame = mountOnScreen(actions, size.X, size.Y)
			local body = frame:FindFirstChild("Body", true)
			local problem = frame:FindFirstChild("Strip panel", true):FindFirstChild("Problem 1", true)

			expect(problem.AbsolutePosition.Y + 12 <= body.AbsolutePosition.Y + body.AbsoluteSize.Y).toBe(true)
			expect(problem:FindFirstAncestorWhichIsA("ScrollingFrame")).never.toBe(nil)
		end
	end)

	it("announces a finished install with Show in Explorer and Undo", function()
		local actions = seeded(false)

		table.insert(
			actions,
			{ type = "setNotice", notice = { kind = "installed", message = "Installed Signal 2.0.3" } }
		)

		local folder = mount(actions, 320, 560)
		local notice = folder:FindFirstChild("Notice", true)

		expect(notice:FindFirstChild("Message", true).Text).toBe("Installed Signal 2.0.3")
		expect(notice:FindFirstChild("Show in Explorer", true)).never.toBe(nil)
		expect(notice:FindFirstChild("Undo", true)).never.toBe(nil)
	end)
end)
