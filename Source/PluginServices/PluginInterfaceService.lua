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
	
			-- Not yet implemented!
			onDeleteButtonClicked = function()
	
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
	
			-- I don't know what this is, but i'm sure there's a good reason for it to exist.
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