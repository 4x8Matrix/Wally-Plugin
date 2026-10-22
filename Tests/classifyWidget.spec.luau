local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local classifyWidget = require(ReplicatedStorage.WallyPlugin.PluginUtilities.classifyWidget)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local figmaFrames = {
	{ 320, 560, "s", "sheet" },
	{ 260, 1200, "s", "inline" },
	{ 220, 240, "xs", "full" },
	{ 300, 300, "s", "full" },
	{ 480, 480, "m", "sheet" },
	{ 720, 720, "l", "side" },
	{ 760, 420, "l", "side" },
	{ 1100, 800, "l", "side" },
	{ 1280, 200, "l", "strip" },
	{ 1500, 160, "l", "stripLine" },
}

describe("classifyWidget", function()
	for _, frame in figmaFrames do
		local width, height, widthClass, surface = table.unpack(frame)

		it(`puts a {width} x {height} widget in {widthClass} rows with a {surface} surface`, function()
			local layout = classifyWidget(width, height)

			expect(layout.widthClass).toBe(widthClass)
			expect(layout.surface).toBe(surface)
		end)
	end

	it("changes row style exactly at 260, 420 and 680 px wide", function()
		expect(classifyWidget(259, 600).widthClass).toBe("xs")
		expect(classifyWidget(260, 600).widthClass).toBe("s")
		expect(classifyWidget(419, 600).widthClass).toBe("s")
		expect(classifyWidget(420, 600).widthClass).toBe("m")
		expect(classifyWidget(679, 600).widthClass).toBe("m")
		expect(classifyWidget(680, 600).widthClass).toBe("l")
	end)

	it("changes surface exactly at 360 and 900 px tall", function()
		expect(classifyWidget(320, 359).surface).toBe("full")
		expect(classifyWidget(320, 360).surface).toBe("sheet")
		expect(classifyWidget(320, 899).surface).toBe("sheet")
		expect(classifyWidget(320, 900).surface).toBe("inline")
	end)

	it("stacks the tabs only when the row opens in place", function()
		expect(classifyWidget(260, 1200).stackedTabs).toBe(true)
		expect(classifyWidget(1100, 1200).stackedTabs).toBe(false)
		expect(classifyWidget(320, 560).stackedTabs).toBe(false)
	end)

	it("sizes the side and strip panels and styles the rows by the room the list keeps beside them", function()
		expect(classifyWidget(760, 420)).toEqual({
			widthClass = "l",
			surface = "side",
			strip = false,
			stackedTabs = false,
			panelWidth = 300,
			rowClass = "m",
		})
		expect(classifyWidget(1100, 800).panelWidth).toBe(374)
		expect(classifyWidget(1100, 800).rowClass).toBe("l")
		expect(classifyWidget(1280, 200).panelWidth).toBe(576)
		expect(classifyWidget(1280, 200).rowClass).toBe("l")
		expect(classifyWidget(680, 200).panelWidth).toBe(520)
		expect(classifyWidget(680, 200).rowClass).toBe("xs")
		expect(classifyWidget(1500, 160).panelWidth).toBe(760)
		expect(classifyWidget(1500, 160).rowClass).toBe("l")
	end)

	it("gives the whole width to the rows when no panel sits beside them", function()
		expect(classifyWidget(320, 560).panelWidth).toBe(0)
		expect(classifyWidget(320, 560).rowClass).toBe("s")
		expect(classifyWidget(220, 240).rowClass).toBe("xs")
	end)

	it("marks both strip surfaces as strips", function()
		expect(classifyWidget(1280, 200).strip).toBe(true)
		expect(classifyWidget(1500, 160).strip).toBe(true)
		expect(classifyWidget(760, 420).strip).toBe(false)
	end)
end)
