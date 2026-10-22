local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Roact = require(ReplicatedStorage.WallyPlugin.Packages.Roact)

local Badge = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.Badge)
local Divider = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.Divider)
local ErrorBlock = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.ErrorBlock)
local Icon = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.Icon)
local Motion = require(ReplicatedStorage.WallyPlugin.PluginInterface.Motion)
local Palette = require(ReplicatedStorage.WallyPlugin.PluginInterface.Palette)
local PaletteProvider = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.PaletteProvider)
local PluginContext = require(ReplicatedStorage.WallyPlugin.PluginContext)
local PrimaryButton = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.PrimaryButton)
local Spinner = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.Spinner)
local Text = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.Text)
local TextField = require(ReplicatedStorage.WallyPlugin.PluginInterface.Components.Common.TextField)

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local handles = {}
local readReduced = Motion.ReadReduced
local light

for _, theme in settings().Studio:GetAvailableThemes() do
	if theme.Name == "Light" then
		light = theme
	end
end

local palette = Palette.from(light)

local function mount(element): Folder
	local folder = Instance.new("Folder")
	local handle = Roact.mount(Roact.createElement(PaletteProvider, { theme = light }, { Element = element }), folder)

	table.insert(handles, { handle = handle, folder = folder })

	return folder
end

--[[
	Mounts `element`, then replaces it with `later` once mounted, the way new props reach a component.
]]
local function mountThen(element, later): Folder
	local folder = Instance.new("Folder")
	local handle = Roact.mount(Roact.createElement(PaletteProvider, { theme = light }, { Element = element }), folder)

	handle = Roact.update(handle, Roact.createElement(PaletteProvider, { theme = light }, { Element = later }))
	table.insert(handles, { handle = handle, folder = folder })

	return folder
end

--[[
	Waits rendered frames, the ones Flipper steps its motors on.
]]
local function frames(count: number)
	for _ = 1, count do
		RunService.RenderStepped:Wait()
	end
end

describe("Common components", function()
	beforeEach(function()
		Motion.ReadReduced = function()
			return false
		end
	end)

	afterEach(function()
		Motion.ReadReduced = readReduced

		for _, mounted in handles do
			Roact.unmount(mounted.handle)
			mounted.folder:Destroy()
		end

		table.clear(handles)
	end)

	it("colours text by its role and sets Builder Mono for code", function()
		local folder = mount(Roact.createFragment({
			Strong = Roact.createElement(Text, { Text = "Signal", Role = "strong" }),
			Version = Roact.createElement(Text, { Text = "2.0.3", Role = "dim", Mono = true }),
		}))
		local strong = folder:FindFirstChild("Strong", true)
		local version = folder:FindFirstChild("Version", true)

		expect(strong.TextColor3).toEqual(palette.strongText)
		expect(strong.FontFace.Family).toBe(PluginContext.PluginSettings.Fonts.Sans)
		expect(version.TextColor3).toEqual(palette.dimText)
		expect(version.FontFace.Family).toBe(PluginContext.PluginSettings.Fonts.Mono)
	end)

	it("tints white icons with their role and leaves coloured ones alone", function()
		local folder = mount(Roact.createFragment({
			Search = Roact.createElement(Icon, { Image = PluginContext.PluginSettings.Icons.Search, Role = "sub" }),
			Warning = Roact.createElement(Icon, { Image = PluginContext.PluginSettings.Icons.Warning, Tinted = false }),
		}))

		expect(folder:FindFirstChild("Search", true).ImageColor3).toEqual(palette.subText)
		expect(folder:FindFirstChild("Warning", true).ImageColor3).toEqual(Color3.new(1, 1, 1))
	end)

	it("draws the primary button in the accent, greyed when disabled", function()
		local folder = mount(Roact.createFragment({
			Install = Roact.createElement(PrimaryButton, { Text = "Install Signal 2.0.3" }),
			Busy = Roact.createElement(PrimaryButton, { Text = "Another install is running", Disabled = true }),
		}))
		local install = folder:FindFirstChild("Install", true):FindFirstChild("Face")
		local busy = folder:FindFirstChild("Busy", true):FindFirstChild("Face")

		expect(install.BackgroundColor3).toEqual(palette.accent)
		expect(install:FindFirstChild("Label", true).TextColor3).toEqual(palette.accentText)
		expect(busy.BackgroundColor3).toEqual(palette.track)
		expect(busy:FindFirstChild("Label", true).TextColor3).toEqual(palette.dimText)
	end)

	it("crossfades the primary button into its disabled colours", function()
		local folder = mountThen(
			Roact.createElement(PrimaryButton, { Text = "Install Signal 2.0.3" }),
			Roact.createElement(PrimaryButton, { Text = "Another install is running", Disabled = true })
		)
		local button = folder:FindFirstChild("Element", true):FindFirstChild("Face")

		frames(1)

		expect(button.BackgroundColor3).never.toEqual(palette.track)

		task.wait(1)

		expect(button.BackgroundColor3).toEqual(palette.track)
	end)

	it("fills the primary button to its progress", function()
		local folder = mount(Roact.createElement(PrimaryButton, { Text = "Downloading 1 of 2", Progress = 0.5 }))
		local fill = folder:FindFirstChild("Fill", true)

		expect(fill.Size.X.Scale).toBeCloseTo(0.5)
		expect(fill.BackgroundColor3).toEqual(palette.accent)
	end)

	it("outlines a text field in the error colour when it has an error", function()
		local folder = mount(Roact.createFragment({
			Plain = Roact.createElement(TextField, { Text = "Signal" }),
			Wrong = Roact.createElement(TextField, { Text = "Signal", Error = true }),
		}))

		expect(folder:FindFirstChild("Plain", true):FindFirstChildOfClass("UIStroke").Color).toEqual(
			palette.fieldBorder
		)
		expect(folder:FindFirstChild("Wrong", true):FindFirstChildOfClass("UIStroke").Color).toEqual(palette.error)
		expect(folder:FindFirstChild("Plain", true):FindFirstChildOfClass("TextBox", true).Text).toBe("Signal")
	end)

	it("shows an active badge in the accent", function()
		local folder = mount(Roact.createFragment({
			Quiet = Roact.createElement(Badge, { Text = "4" }),
			Active = Roact.createElement(Badge, { Text = "5", Active = true }),
		}))

		expect(folder:FindFirstChild("Quiet", true).BackgroundColor3).toEqual(palette.track)
		expect(folder:FindFirstChild("Active", true).BackgroundColor3).toEqual(palette.accent)
	end)

	it("flashes the badge when its count changes", function()
		local folder = mountThen(Roact.createElement(Badge, { Text = "4" }), Roact.createElement(Badge, { Text = "5" }))
		local badge = folder:FindFirstChild("Element", true)

		frames(2)

		expect(badge.BackgroundColor3).never.toEqual(palette.track)

		task.wait(1.2)

		expect(badge.BackgroundColor3).toEqual(palette.track)
	end)

	it("fades an error block in", function()
		local folder = mount(Roact.createElement(ErrorBlock, { Text = "the registry did not answer" }))
		local block = folder:FindFirstChild("Element", true)

		expect(block.BackgroundTransparency > 0.95).toBe(true)

		task.wait(1)

		expect(block.BackgroundTransparency).toBeCloseTo(Palette.WashTransparency, 3)
		expect(block:FindFirstChild("Message", true).TextTransparency).toBeCloseTo(0, 3)
	end)

	it("draws dividers and spinners from the palette", function()
		local folder = mount(Roact.createFragment({
			Line = Roact.createElement(Divider),
			Busy = Roact.createElement(Spinner, { Role = "accent" }),
		}))

		expect(folder:FindFirstChild("Line", true).BackgroundColor3).toEqual(palette.divider)
		expect(folder:FindFirstChildWhichIsA("ImageLabel", true).ImageColor3).toEqual(palette.accent)
	end)

	it("draws the spinner turning inside a list layout, which ignores the rotation of what it places", function()
		local screen = Instance.new("ScreenGui")
		local row = Instance.new("Frame")

		row.Size = UDim2.fromOffset(200, 40)
		row.Parent = screen
		Instance.new("UIListLayout").Parent = row
		screen.Parent = StarterGui

		local handle = Roact.mount(
			Roact.createElement(PaletteProvider, { theme = light }, {
				Spinner = Roact.createElement(Spinner, { Size = 32, LayoutOrder = 1 }),
			}),
			row
		)

		table.insert(handles, { handle = handle, folder = screen })
		frames(3)

		local image = row:FindFirstChildWhichIsA("ImageLabel", true)
		local first = image.AbsoluteRotation

		frames(3)

		expect(image.AbsoluteRotation).toBeCloseTo(image.Rotation, 3)
		expect(image.AbsoluteRotation).never.toBeCloseTo(first, 3)
	end)
end)
