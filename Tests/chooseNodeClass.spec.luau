local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)

local chooseNodeClass = require(ReplicatedStorage.WallyPlugin.PluginUtilities.chooseNodeClass)

local REQUIRED = { path = "src", optional = false }
local OPTIONAL = { path = "src", optional = true }
local MISSING_INFORMATION = 'Instance "Node" is missing some required information. One of the following must be true: '
	.. "$className must be set to the name of a Roblox class; $path must be set to a path of an instance; "
	.. "the instance must be a known service, like ReplicatedStorage"

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function both(className: string, pathClass: string): string
	return `ClassName for Instance "Node" was specified in both the project file (as "{className}") and from the `
		.. `filesystem (as "{pathClass}"). If $className and $path are both set, $path must refer to a Folder. `
		.. "Filesystem path: src"
end

describe("chooseNodeClass", function()
	it("takes $className when the path gives no class, inferred or not (rows 1 and 4)", function()
		expect(chooseNodeClass("Node", "Model", nil, nil, nil)).toEqual({ ok = true, value = "Model" })
		expect(chooseNodeClass("Node", "Folder", nil, "StarterPlayerScripts", nil)).toEqual({
			ok = true,
			value = "Folder",
		})
		expect(chooseNodeClass("Node", "Model", nil, nil, REQUIRED)).toEqual({ ok = true, value = "Model" })
	end)

	it("takes the path's class, or the inferred one over a Folder (rows 2 and 5)", function()
		expect(chooseNodeClass("Node", nil, "ModuleScript", nil, REQUIRED)).toEqual({
			ok = true,
			value = "ModuleScript",
		})
		expect(chooseNodeClass("Node", nil, "Folder", "StarterPlayerScripts", REQUIRED)).toEqual({
			ok = true,
			value = "StarterPlayerScripts",
		})
		expect(chooseNodeClass("Node", nil, "ModuleScript", "StarterPlayerScripts", REQUIRED)).toEqual({
			ok = true,
			value = "ModuleScript",
		})
	end)

	it("takes the inferred class when nothing else gives one (row 3)", function()
		expect(chooseNodeClass("Node", nil, nil, "Terrain", nil)).toEqual({ ok = true, value = "Terrain" })
		expect(chooseNodeClass("Node", nil, nil, "Terrain", REQUIRED)).toEqual({ ok = true, value = "Terrain" })
	end)

	it("takes $className over a Folder path and refuses any other path class, even the same one (row 6)", function()
		expect(chooseNodeClass("Node", "Model", "Folder", nil, REQUIRED)).toEqual({ ok = true, value = "Model" })
		expect(chooseNodeClass("Node", "Model", "Folder", "StarterPlayerScripts", REQUIRED)).toEqual({
			ok = true,
			value = "Model",
		})
		expect(chooseNodeClass("Node", "ModuleScript", "ModuleScript", nil, REQUIRED)).toEqual({
			ok = false,
			error = { path = "", message = both("ModuleScript", "ModuleScript") },
		})
		expect(chooseNodeClass("Node", "Folder", "Script", nil, REQUIRED)).toEqual({
			ok = false,
			error = { path = "", message = both("Folder", "Script") },
		})
	end)

	it("omits a node whose optional path gives nothing (row 7)", function()
		expect(chooseNodeClass("Node", nil, nil, nil, OPTIONAL)).toEqual({ ok = true })
	end)

	it("refuses a node whose required path gives nothing (row 8)", function()
		expect(chooseNodeClass("Node", nil, nil, nil, REQUIRED)).toEqual({
			ok = false,
			error = { path = "", message = '$path "src" could not be turned into an instance' },
		})
	end)

	it("refuses a node with no class and no path (row 9)", function()
		expect(chooseNodeClass("Node", nil, nil, nil, nil)).toEqual({
			ok = false,
			error = { path = "", message = MISSING_INFORMATION },
		})
	end)
end)
