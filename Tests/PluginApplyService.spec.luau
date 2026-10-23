local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginApplyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginApplyService)
local PluginPropertyService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginPropertyService)
local PluginReflectionService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginReflectionService)

local CONTENTS = '[{"key":"a","source":"Hi","values":{"en":"Hi"}}]'

local afterEach = JestGlobals.afterEach
local beforeEach = JestGlobals.beforeEach
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local reporter = PluginApplyService.Reporter
local warnings = {}

describe("PluginApplyService", function()
	beforeEach(function()
		table.clear(warnings)

		PluginApplyService.Reporter = {
			Warn = function(_, message: string)
				table.insert(warnings, message)
			end,
		}
	end)

	afterEach(function()
		PluginApplyService.Reporter = reporter
	end)

	it("sets properties, adds tags and sets attributes", function()
		local part = Instance.new("Part")

		expect(PluginApplyService:Apply(part, {
			Anchored = true,
			Attributes = { Health = 100, Label = "x" },
			Material = Enum.Material.Wood,
			Tags = { "b", "a", "b" },
		})).toEqual({ ok = true })
		expect(part.Anchored).toBe(true)
		expect(part.Material).toBe(Enum.Material.Wood)
		expect(part:GetAttributes()).toEqual({ Health = 100, Label = "x" })
		expect(part:HasTag("a") and part:HasTag("b")).toBe(true)
		expect(#part:GetTags()).toBe(2)
		part:Destroy()
	end)

	it("replaces the tags and attributes an instance already had, and clears a property to nil", function()
		local part = Instance.new("Part")

		part:AddTag("old")
		part:SetAttribute("Old", true)
		part.CustomPhysicalProperties = PhysicalProperties.new(1, 1, 1)

		expect(PluginApplyService:Apply(part, {
			Attributes = { New = 1 },
			CustomPhysicalProperties = PluginPropertyService.Nil,
			Tags = { "new" },
		})).toEqual({ ok = true })
		expect(part:GetTags()).toEqual({ "new" })
		expect(part:GetAttributes()).toEqual({ New = 1 })
		expect(part.CustomPhysicalProperties).toBe(nil)
		part:Destroy()
	end)

	it("leaves out with a warning an attribute name Studio will not take from a plugin", function()
		local folder = Instance.new("Folder")

		expect(PluginApplyService:Apply(folder, {
			Attributes = { ["has space"] = true, RBXthing = true, [string.rep("x", 101)] = true, Fine = true },
		})).toEqual({ ok = true })
		expect(folder:GetAttributes()).toEqual({ Fine = true })
		expect(#warnings).toBe(3)
		folder:Destroy()
	end)

	it(
		"sets LocalizationTable.Contents with the setter PluginReflectionService names, as assigning it fails",
		function()
			local localizationTable = Instance.new("LocalizationTable")

			expect(PluginReflectionService:FindProperty("LocalizationTable", "Contents").setter).toBe("SetContents")
			expect(PluginApplyService:Apply(localizationTable, { Contents = CONTENTS })).toEqual({ ok = true })
			expect(localizationTable:GetContents()).toBe(CONTENTS)
			localizationTable:Destroy()
		end
	)

	it("leaves Contents that is not JSON empty with a warning, as Studio loads Rojo's build of it", function()
		local localizationTable = Instance.new("LocalizationTable")

		localizationTable:SetContents(CONTENTS)

		expect(PluginApplyService:Apply(localizationTable, { Contents = "not json" })).toEqual({ ok = true })
		expect(localizationTable:GetContents()).toBe("[]")
		expect(#warnings).toBe(1)
		localizationTable:Destroy()
	end)

	it("sets a Source of 200000 bytes or more, which Studio will not let a plugin assign", function()
		for _, className in { "ModuleScript", "Script", "LocalScript" } do
			local container = Instance.new(className) :: any
			local source = `-- {className}\n` .. string.rep("a", 200000)

			expect(PluginApplyService:Apply(container, { Source = source })).toEqual({ ok = true })
			expect(container.Source).toBe(source)
			container:Destroy()
		end
	end)

	it("fails with the property's name when Studio refuses a value", function()
		local part = Instance.new("Part")
		local applied = PluginApplyService:Apply(part, { Size = true })

		part:Destroy()
		expect(applied.ok).toBe(false)
		expect(applied.error.path).toBe("")
		expect(string.sub(applied.error.message, 1, 28)).toBe("Part.Size could not be set: ")
	end)
end)
