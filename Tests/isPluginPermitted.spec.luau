local ReflectionService = game:GetService("ReflectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local PluginReflectionService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginReflectionService)

local isPluginPermitted = require(ReplicatedStorage.WallyPlugin.PluginUtilities.isPluginPermitted)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function creationPermit(className: string): SecurityCapabilities?
	return ReflectionService:GetClass(className, PluginReflectionService.ReflectionFilter).Permits.New
end

describe("isPluginPermitted", function()
	it("permits what a plugin can create, whatever capabilities it asks for", function()
		expect(isPluginPermitted(creationPermit("Folder"))).toBe(true)
		expect(isPluginPermitted(creationPermit("Part"))).toBe(true)
		expect(isPluginPermitted(creationPermit("Animation"))).toBe(true)
	end)

	it("refuses permits needing a capability a plugin lacks, and no permit at all", function()
		expect(isPluginPermitted(creationPermit("PhysicsActivitySensor"))).toBe(false)
		expect(isPluginPermitted(creationPermit("Player"))).toBe(false)
		expect(isPluginPermitted(creationPermit("DebuggerWatch"))).toBe(false)
		expect(isPluginPermitted(creationPermit("ExplorerFilter"))).toBe(false)
		expect(isPluginPermitted(creationPermit("Workspace"))).toBe(false)
		expect(isPluginPermitted(nil)).toBe(false)
	end)
end)
