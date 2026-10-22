local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Flipper = require(ReplicatedStorage.WallyPlugin.Packages.Flipper)

local Motion = require(ReplicatedStorage.WallyPlugin.PluginInterface.Motion)

local afterEach = JestGlobals.afterEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local readReduced = Motion.ReadReduced

local function reduceMotion(reduced: boolean)
	Motion.ReadReduced = function()
		return reduced
	end
end

describe("Motion", function()
	afterEach(function()
		Motion.ReadReduced = readReduced
	end)

	it("springs towards a goal with the preset's frequency and damping", function()
		reduceMotion(false)

		expect(Motion.Presets.sheet).toEqual({ frequency = 4, dampingRatio = 0.9 })
		expect(Motion:Goal(1, "sheet")).toEqual(Flipper.Spring.new(1, { frequency = 4, dampingRatio = 0.9 }))
	end)

	it("jumps straight to the goal when reduced motion is on", function()
		reduceMotion(true)

		expect(getmetatable(Motion:Goal(1, "sheet"))).toBe(getmetatable(Flipper.Instant.new(0)))
	end)

	it("reads Roblox's reduced motion setting by default", function()
		expect(typeof(Motion:ReadReduced())).toBe("boolean")
	end)

	it("has a preset for every surface that moves", function()
		for _, preset in { "sheet", "tab", "selection", "progress", "expand", "push", "hover", "press", "fade" } do
			expect(Motion.Presets[preset]).never.toBe(nil)
		end
	end)
end)
