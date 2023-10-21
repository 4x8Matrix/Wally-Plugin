local RoactRodux = require(script.Parent.Parent.Packages.RoactRodux)
local Roact = require(script.Parent.Parent.Packages.Roact)
local Console = require(script.Parent.Parent.Packages.Console)

local VirtualPackage = require(script.Parent.Parent.PluginClasses.VirtualPackage)

local RoactApp = require(script.Parent.Parent.PluginInterface)
local RoduxStore = require(script.Parent.Parent.PluginInterface.Store)

local PluginWallyApiService = require(script.Parent.PluginWallyApiService)
local PluginPackageService = require(script.Parent.PluginPackageService)
local PluginActionService = require(script.Parent.PluginActionService)
local PluginContextService = require(script.Parent.PluginContextService)

local PluginInterfaceService = { }

PluginInterfaceService.Reporter = Console.new(`🌟 {script.Name}`)
PluginInterfaceService.InstalledPackageList = { }
PluginInterfaceService.RoactHandle = { }

PluginInterfaceService.QueryThread = nil

function PluginInterfaceService.CreateRoduxEvent(_: PluginInterfaceService, eventName: string, eventData: { [any]: any })
	eventData["type"] = eventName
	
	return eventData
end

--[[
	Dynamic function to query the wally api in <seconds>, however if this function is several times, it will
		cancel the last query request. Therefore allowing us to make 1 request every time the user
		stops typing.
]]
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
			-- When the search bar text has been updated
			onSearchTextUpdated = function(textInput: string)
				if textInput == "" then
					RoduxStore:dispatch(self:CreateRoduxEvent("setSearchedPackages", {
						packageArray = { }
					}))

					return
				end

				self:QueryIn(0.25, textInput)
			end,
	
			-- When the download button has been clicked
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
	
			-- When the developer attempts to remove a package from the project
			onDeleteButtonClicked = function(selectedPackageName)
				local packageInformation = VirtualPackage.parse(selectedPackageName)
				local selectedPackage = VirtualPackage.from(
					packageInformation.Scope,
					packageInformation.Name,
					packageInformation.Version
				)

				PluginPackageService:RemovePackageFromIndex(selectedPackage)
			end,
	
			-- When the developer right-clicks on the package instead of pressing the download button
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
	
			-- When the developer right-clicks on an installed package instead of pressing the delete button
			onInstallLabelRightClicked = function(selectedPackageName)
				local packageInformation = VirtualPackage.parse(selectedPackageName)
				local selectedPackage = VirtualPackage.from(
					packageInformation.Scope,
					packageInformation.Name,
					packageInformation.Version
				)

				PluginPackageService:SetSelectedPackage(selectedPackage)
				PluginContextService:ShowInstalledContextMenuAsync()
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

function PluginInterfaceService.SetTransitionState(self: PluginInterfaceService, state: boolean)
	RoduxStore:dispatch(self:CreateRoduxEvent("setLoadingState", {
		state = state
	}))
end

function PluginInterfaceService.UpdateInstalledPackageList(self: PluginInterfaceService)
	self.InstalledPackageList = { }

	for _, packageObject: VirtualPackage.VirtualPackage in PluginPackageService:GetPackagesInIndex() do
		table.insert(self.InstalledPackageList, VirtualPackage.into({
			Scope = packageObject.Scope,
			Name = packageObject.Name,
			Version = packageObject.Version
		}))
	end

	RoduxStore:dispatch(self:CreateRoduxEvent("setInstalledPackages", {
		packageArray = self.InstalledPackageList
	}))
end

function PluginInterfaceService.OnStart(self: PluginInterfaceService)
	self:UpdateRoduxCallbacks()
	self:UpdateInstalledPackageList()
	
	self.PackageAddedToIndexConnection = PluginPackageService.OnPackageAddedToIndex:Connect(function()
		self:UpdateInstalledPackageList()
	end)

	self.PackageRemovedFromIndexConnection = PluginPackageService.OnPackageRemovedFromIndex:Connect(function()
		self:UpdateInstalledPackageList()
	end)

	self.ActionStartedConnection = PluginActionService.ActionStarted:Connect(function()
		if not PluginActionService:IsTransitionableActionActive() then
			-- if there's any transitionable action active, then enable transition

			return
		end

		self:SetTransitionState(true)
	end)

	self.ActionEndedConnection = PluginActionService.ActionEnded:Connect(function(actionName: string)
		if not PluginActionService:IsTransitionableAction(actionName) then
			-- non-transitionable actions don't disable transition.

			return
		end

		if PluginActionService:IsTransitionableActionActive() then
			-- if another transitionable action is active, don't disable transition.

			return
		end

		self:SetTransitionState(false)
	end)
end

function PluginInterfaceService.OnStop(self: PluginInterfaceService)
	self.PackageAddedToIndexConnection:Disconnect()
	self.PackageRemovedFromIndexConnection:Disconnect()
end

export type PluginInterfaceService = typeof(PluginInterfaceService)

return PluginInterfaceService