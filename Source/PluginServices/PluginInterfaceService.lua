local RoactRodux = require(script.Parent.Parent.Packages.RoactRodux)
local Roact = require(script.Parent.Parent.Packages.Roact)
local Console = require(script.Parent.Parent.Packages.Console)

local VirtualPackage = require(script.Parent.Parent.PluginClasses.VirtualPackage)

local RoactApp = require(script.Parent.Parent.PluginInterface)
local RoduxStore = require(script.Parent.Parent.PluginInterface.Store)

local PluginWallyApiService = require(script.Parent.PluginWallyApiService)
local PluginPackageService = require(script.Parent.PluginPackageService)
local PluginContextService = require(script.Parent.PluginContextService)

local PluginInterfaceService = { }

PluginInterfaceService.Reporter = Console.new(`🌟 {script.Name}`)
PluginInterfaceService.RoactHandle = { }

PluginInterfaceService.QueryThread = nil

function PluginInterfaceService.CreateRoduxEvent(_: PluginInterfaceService, eventName: string, eventData: { [any]: any })
	eventData["type"] = eventName
	
	return eventData
end

function PluginInterfaceService.QueryIn(self: PluginInterfaceService, seconds: number, textInput: string)
	if self.QueryThread then
		task.cancel(self.QueryThread)
	end
	
	self.QueryThread = task.delay(seconds, function()
		self.QueryThread = nil

		PluginWallyApiService:QueryWallyApiAsync(textInput):andThen(function(wallyPackageInformation)
			local searchQueryList = { }
	
			for _, packageData in wallyPackageInformation do
				table.insert(searchQueryList, VirtualPackage.into({
					Scope = packageData.scope,
					Name = packageData.name,
					Version = packageData.versions[1]
				}))
			end
	
			RoduxStore:dispatch(self:CreateRoduxEvent("setSearchedPackages", {
				packageArray = searchQueryList
			}))
		end):catch(function(exception)
			self.Reporter:Warn(`Failed to query '{textInput}', with error: {exception}`)
		end)
	end)
end

function PluginInterfaceService.UpdateRoduxCallbacks(self: PluginInterfaceService)
	RoduxStore:dispatch(self:CreateRoduxEvent("setCallbacks", {
		callbacks = {
			onSearchTextUpdated = function(textInput: string)
				if textInput == "" then
					RoduxStore:dispatch(self:CreateRoduxEvent("setSearchedPackages", {
						packageArray = { }
					}))

					return
				end

				self:QueryIn(1, textInput)
			end,
	
			onDownloadButtonClicked = function(selectedPackageName)
				local packageInformation = VirtualPackage.parse(selectedPackageName)
				local selectedPackage = VirtualPackage.from(
					packageInformation.Scope,
					packageInformation.Name,
					packageInformation.Version
				)

				PluginPackageService:SetSelectedPackage(selectedPackage)
				PluginContextService:ShowDownloadContextMenuAsync()
			end,
	
			onDeleteButtonClicked = function()
	
			end,
	
			onSuggestedLabelRightClicked = function(selectedPackageName)
				local packageInformation = VirtualPackage.parse(selectedPackageName)
				local selectedPackage = VirtualPackage.from(
					packageInformation.Scope,
					packageInformation.Name,
					packageInformation.Version
				)

				PluginPackageService:SetSelectedPackage(selectedPackage)
				PluginContextService:ShowDownloadContextMenuAsync()
			end,
	
			onInstallLabelRightClicked = function()
	
			end
		}
	}))
end

function PluginInterfaceService.MountInterfaceOnto(self: PluginInterfaceService, instance: Instance)
	self.RoactHandle = Roact.mount(
		Roact.createElement(RoactRodux.StoreProvider, {
			store = RoduxStore,
		}, {
			MainInterface = Roact.createElement(RoactApp, {}),
		}),
		instance
	)
end

function PluginInterfaceService.UnmountInterface(self: PluginInterfaceService)
	Roact.unmount(self.RoactHandle)

	self.RoactHandle = nil
end

function PluginInterfaceService.OnStart(self: PluginInterfaceService)
	self:UpdateRoduxCallbacks()
end

export type PluginInterfaceService = typeof(PluginInterfaceService)

return PluginInterfaceService