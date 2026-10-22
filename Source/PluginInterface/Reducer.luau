local Rodux = require(script.Parent.Parent.Packages.Rodux)
local Sift = require(script.Parent.Parent.Packages.Sift)

local IDLE_DETAIL = { status = "idle", versions = {}, realms = {} }

local function noop() end

return Rodux.createReducer({
	tab = "browse",
	query = "",
	search = { status = "idle", results = {} },
	installed = {},
	selection = nil,
	detail = IDLE_DETAIL,
	form = { realm = "shared", alias = "", errors = {} },
	operation = nil,
	notice = nil,

	onSearchTextUpdated = noop,
	onSearchSubmitted = noop,
	onRetrySearch = noop,
	onTabSelected = noop,
	onResultSelected = noop,
	onInstalledSelected = noop,
	onSelectionCleared = noop,
	onFormChanged = noop,
	onInstallClicked = noop,
	onRemoveClicked = noop,
	onShowInExplorer = noop,
	onUndo = noop,
	onNoticeDismissed = noop,
}, {
	setCallbacks = function(state, action)
		return Sift.Dictionary.merge(state, action.callbacks)
	end,

	setTab = function(state, action)
		return Sift.Dictionary.merge(state, { tab = action.tab })
	end,

	setQuery = function(state, action)
		return Sift.Dictionary.merge(state, { query = action.query })
	end,

	setSearch = function(state, action)
		return Sift.Dictionary.merge(state, { search = action.search })
	end,

	setInstalled = function(state, action)
		return Sift.Dictionary.merge(state, { installed = action.installed })
	end,

	setSelection = function(state, action)
		return Sift.Dictionary.merge(state, {
			selection = action.selection or Sift.None,
			detail = IDLE_DETAIL,
			form = Sift.Dictionary.merge(state.form, { errors = {} }),
		})
	end,

	setDetail = function(state, action)
		return Sift.Dictionary.merge(state, { detail = action.detail })
	end,

	setForm = function(state, action)
		return Sift.Dictionary.merge(state, { form = Sift.Dictionary.merge(state.form, action.form) })
	end,

	setOperation = function(state, action)
		return Sift.Dictionary.merge(state, { operation = action.operation or Sift.None })
	end,

	setNotice = function(state, action)
		return Sift.Dictionary.merge(state, { notice = action.notice or Sift.None })
	end,
})
