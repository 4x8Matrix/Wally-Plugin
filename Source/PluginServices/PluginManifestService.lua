--[[
	 To Do: either implement the manifest feature, or remove Service.
	 	This module doesn't do anything at the moment.
]]

local ServerStorage = game:GetService("ServerStorage")

local Trove = require(script.Parent.Parent.Packages.Trove)
local Console = require(script.Parent.Parent.Packages.Console)
local Signal = require(script.Parent.Parent.Packages.Signal)

local PluginManifestService = { }

PluginManifestService.Trove = Trove.new()
PluginManifestService.ManifestTrove = Trove.new()
PluginManifestService.Reporter = Console.new(`🍃 {script.Name}`)
PluginManifestService.Manifest = ServerStorage:FindFirstChild("WallyManifest")

PluginManifestService.ManifestUpdated = Signal.new()

function PluginManifestService.CreateDefaultManifest(_: PluginManifestService)
	local manifestModule = script.Parent.Parent.PluginBlobs.TemplateManifest:Clone()

	manifestModule.Name = "WallyManifest"
	manifestModule.Parent = ServerStorage
	
	return manifestModule
end

function PluginManifestService.AssertManifest(self: PluginManifestService)
	if not self.Manifest then
		self.Manifest = self:CreateDefaultManifest()
	end

	self.ManifestTrove:Add(self.Manifest:GetPropertyChangedSignal("Source"):Connect(function()
		PluginManifestService.ManifestUpdated:Fire()
	end))

	self.ManifestTrove:Add(self.Manifest.AncestryChanged:Connect(function()
		if self.Manifest.Parent then
			return
		end

		self.ManifestTrove:Destroy()
		self.ManifestTrove = Trove.new()

		self.Manifest = nil

		self.Reporter:Warn(`Manifest was removed, replacting Manifest with template module!`)

		self:AssertManifest()
	end))
end

function PluginManifestService.SpecialRequireModule(self: PluginManifestService, module: ModuleScript)
	local moduleClone = module:Clone()
	local success, response = pcall(require, moduleClone)

	moduleClone:Destroy()

	if not success then
		self.Reporter:Warn(`Failed to parse 'WallyManifest' file: {response}`)
	end
	
	return success and response or { }
end

function PluginManifestService.FetchPackageDetails(self: PluginManifestService)
	local manifest = self:SpecialRequireModule(self.Manifest)

	return manifest.Package
end

function PluginManifestService.FetchDependencies(self: PluginManifestService)
	local manifest = self:SpecialRequireModule(self.Manifest)

	return manifest.Dependencies
end

function PluginManifestService.FetchServerDependencies(self: PluginManifestService)
	local manifest = self:SpecialRequireModule(self.Manifest)

	return manifest.ServerDependencies
end

function PluginManifestService.FetchDeveloperDependencies(self: PluginManifestService)
	local manifest = self:SpecialRequireModule(self.Manifest)

	return manifest.DeveloperDependencies
end

function PluginManifestService.OnInit(_: PluginManifestService)
	-- self:AssertManifest()
end

function PluginManifestService.OnStop(self: PluginManifestService)
	self.Trove:Destroy()
	self.ManifestTrove:Destroy()
end

export type PluginManifestService = typeof(PluginManifestService)

return PluginManifestService