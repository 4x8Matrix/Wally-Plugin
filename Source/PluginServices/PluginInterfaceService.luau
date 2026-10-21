local ChangeHistoryService = game:GetService("ChangeHistoryService")

local RoactRodux = require(script.Parent.Parent.Packages.RoactRodux)
local Roact = require(script.Parent.Parent.Packages.Roact)
local Console = require(script.Parent.Parent.Packages.Console)
local Trove = require(script.Parent.Parent.Packages.Trove)

local RoactApp = require(script.Parent.Parent.PluginInterface)
local RoduxStore = require(script.Parent.Parent.PluginInterface.Store)

local PluginWallyApiService = require(script.Parent.PluginWallyApiService)
local PluginPackageService = require(script.Parent.PluginPackageService)
local PluginActionService = require(script.Parent.PluginActionService)
local PluginContextService = require(script.Parent.PluginContextService)

local describeRequestFailure = require(script.Parent.Parent.PluginUtilities.describeRequestFailure)
local pickDefaultVersion = require(script.Parent.Parent.PluginUtilities.pickDefaultVersion)

local PluginInterfaceService = { }

PluginInterfaceService.Reporter = Console.new(`🌟 {script.Name}`)
PluginInterfaceService.Trove = Trove.new()
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
				local default = pickDefaultVersion(packageData.versions)

				if default.ok then
					table.insert(searchQueryList, `{packageData.scope}/{packageData.name}@{default.value}`)
				end
			end

			RoduxStore:dispatch(self:CreateRoduxEvent("setSearchedPackages", {
				packageArray = searchQueryList
			}))
		end):catch(function(exception)
			self.Reporter:Warn(`Failed to query '{textInput}', with error: {describeRequestFailure(exception)}`)
		end)
	end)
end

--[[
	The installed package whose id is `id`, or nil when the list the interface shows is out of date.
]]
function PluginInterfaceService.FindInstalled(_: PluginInterfaceService, id: string)
	for _, installed in PluginPackageService:GetInstalled() do
		if installed.id == id then
			return installed
		end
	end

	return
end

--[[
	The selection a search row stands for: the package name without its version.
]]
function PluginInterfaceService.CreateSearchSelection(_: PluginInterfaceService, selectedPackageName: string)
	return { Name = string.match(selectedPackageName, "^(.+)@") }
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
	
			onDownloadButtonClicked = function(selectedPackageName: string)
				PluginPackageService:SetSelectedPackage(self:CreateSearchSelection(selectedPackageName))
				PluginContextService:ShowDownloadContextMenuAsync()
			end,

			onDeleteButtonClicked = function(selectedPackageName: string)
				local installed = self:FindInstalled(selectedPackageName)

				if installed then
					PluginPackageService:RemoveAsync(installed.alias, installed.realm):await()
				end
			end,

			onSuggestedLabelRightClicked = function(selectedPackageName: string)
				PluginPackageService:SetSelectedPackage(self:CreateSearchSelection(selectedPackageName))
				PluginContextService:ShowDownloadContextMenuAsync()
			end,

			onInstallLabelRightClicked = function(selectedPackageName: string)
				local installed = self:FindInstalled(selectedPackageName)

				if not installed then
					self.Reporter:Warn(`{selectedPackageName} is no longer installed; the installed list was out of date`)
					self:UpdateInstalledPackageList()

					return
				end

				PluginPackageService:SetSelectedPackage({ Alias = installed.alias, Realm = installed.realm })
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

	for _, installed in PluginPackageService:GetInstalled() do
		table.insert(self.InstalledPackageList, installed.id)
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

	self.Trove:Add(ChangeHistoryService.OnUndo:Connect(function()
		self:UpdateInstalledPackageList()
	end))

	self.Trove:Add(ChangeHistoryService.OnRedo:Connect(function()
		self:UpdateInstalledPackageList()
	end))

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
	self.Trove:Destroy()
end

export type PluginInterfaceService = typeof(PluginInterfaceService)

return PluginInterfaceService