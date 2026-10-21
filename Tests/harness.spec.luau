local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Console = require(ReplicatedStorage.WallyPlugin.Packages.Console)
local Flipper = require(ReplicatedStorage.WallyPlugin.Packages.Flipper)
local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Loader = require(ReplicatedStorage.WallyPlugin.Packages.Loader)
local Promise = require(ReplicatedStorage.WallyPlugin.Packages.Promise)
local RateLimit = require(ReplicatedStorage.WallyPlugin.Packages.RateLimit)
local Roact = require(ReplicatedStorage.WallyPlugin.Packages.Roact)
local RoactFlipper = require(ReplicatedStorage.WallyPlugin.Packages.RoactFlipper)
local RoactRodux = require(ReplicatedStorage.WallyPlugin.Packages.RoactRodux)
local Rodux = require(ReplicatedStorage.WallyPlugin.Packages.Rodux)
local Sift = require(ReplicatedStorage.WallyPlugin.Packages.Sift)
local Signal = require(ReplicatedStorage.WallyPlugin.Packages.Signal)
local StudioComponents = require(ReplicatedStorage.WallyPlugin.Packages.StudioComponents)
local Trove = require(ReplicatedStorage.WallyPlugin.Packages.Trove)
local ZZLib = require(ReplicatedStorage.WallyPlugin.Packages.ZZLib)

local PluginWallyApiService = require(ReplicatedStorage.WallyPlugin.PluginServices.PluginWallyApiService)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("test harness", function()
	it("runs specs", function()
		expect(1 + 1).toBe(2)
	end)

	it("loads the plugin and every dependency through the pesde packages", function()
		for _, dependency in
			{
				Console,
				Flipper,
				Loader,
				Promise,
				RateLimit,
				Roact,
				RoactFlipper,
				RoactRodux,
				Rodux,
				Sift,
				Signal,
				StudioComponents,
				Trove,
				ZZLib
			}
		do
			expect(dependency).never.toBe(nil)
		end

		expect(type(PluginWallyApiService.RequestAsync)).toBe("function")
	end)
end)
