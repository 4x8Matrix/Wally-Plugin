local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginReflectionService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginReflectionService)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("PluginReflectionService", function()
	describe("classes", function()
		it("knows which classes a plugin can create", function()
			expect(PluginReflectionService:ClassExists("Folder")).toBe(true)
			expect(PluginReflectionService:ClassExists("ModuleScript")).toBe(true)
			expect(PluginReflectionService:ClassExists("NotAClass")).toBe(false)
			expect(PluginReflectionService:ClassExists("Workspace")).toBe(false)
			expect(PluginReflectionService:ClassExists("DataModel")).toBe(false)
			expect(PluginReflectionService:ClassExists("PhysicsActivitySensor")).toBe(false)
			expect(PluginReflectionService:ClassExists("Player")).toBe(false)
		end)

		it("knows which classes are services", function()
			expect(PluginReflectionService:IsService("Workspace")).toBe(true)
			expect(PluginReflectionService:IsService("ReplicatedStorage")).toBe(true)
			expect(PluginReflectionService:IsService("Folder")).toBe(false)
			expect(PluginReflectionService:IsService("NotAClass")).toBe(false)
		end)

		it("reads a class once and remembers an unknown one as false", function()
			expect(PluginReflectionService:GetClass("Folder")).toBe(PluginReflectionService:GetClass("Folder"))
			expect((PluginReflectionService:GetClass("NotAClass"))).toBe(nil)
			expect(PluginReflectionService.Classes.NotAClass).toBe(false)
		end)
	end)

	describe("properties", function()
		it("records the type Rojo resolves a value against and the type its writer writes", function()
			expect(PluginReflectionService:FindProperty("Part", "Color")).toEqual({
				rojoType = "Color3",
				writtenType = "Color3uint8",
				writable = true,
			})
			expect(PluginReflectionService:FindProperty("Part", "Material")).toEqual({
				rojoType = "Enum",
				writtenType = "Enum",
				enumType = "Material",
				writable = true,
			})
			expect(PluginReflectionService:FindProperty("ObjectValue", "Value").rojoType).toBe("Ref")
			expect(PluginReflectionService:FindProperty("StringValue", "Value").rojoType).toBe("String")
			expect(PluginReflectionService:FindProperty("Folder", "Tags").rojoType).toBe("Tags")
			expect(PluginReflectionService:FindProperty("Folder", "Attributes").rojoType).toBe("Attributes")
		end)

		it("records whether a plugin can set a property and the method that sets it where assigning fails", function()
			expect(PluginReflectionService:FindProperty("Part", "size").writable).toBe(false)
			expect(PluginReflectionService:FindProperty("LocalizationTable", "Contents")).toEqual({
				rojoType = "String",
				writtenType = "String",
				writable = true,
				setter = "SetContents",
			})
		end)

		it("finds nothing for an unknown property or class", function()
			expect(PluginReflectionService:FindProperty("Part", "Bogus")).toBe(nil)
			expect(PluginReflectionService:FindProperty("NotAClass", "Value")).toBe(nil)
		end)
	end)
end)
