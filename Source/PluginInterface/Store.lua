local Rodux = require(script.Parent.Parent.Packages.Rodux)
local Sift = require(script.Parent.Parent.Packages.Sift)

return Rodux.Store.new(Rodux.createReducer({
	searchedPackagesArray = { },
	installedPackagesArray = { },

	onInstallLabelRightClicked = function() end,
	onSuggestedLabelRightClicked = function() end,

	onDeleteButtonClicked = function() end,
	onDownloadButtonClicked = function() end,

	onSearchTextUpdated = function() end,
}, {
	setCallbacks = function(state, action)
		return Sift.Dictionary.merge(state, action.callbacks)
	end,

	setSearchedPackages = function(state, action)
		return Sift.Dictionary.merge(state, {
			searchedPackagesArray = action.packageArray
		})
	end,

	setInstalledPackages = function(state, action)
		return Sift.Dictionary.merge(state, {
			installedPackagesArray = action.packageArray
		})
	end,
}))
