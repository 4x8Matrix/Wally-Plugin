local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.Packages.JestGlobals)
local Rodux = require(ReplicatedStorage.WallyPlugin.Packages.Rodux)

local Reducer = require(ReplicatedStorage.WallyPlugin.PluginInterface.Reducer)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it
local selection = { kind = "result", scope = "sleitnick", name = "signal" }

local function newStore()
	return Rodux.Store.new(Reducer)
end

describe("Reducer", function()
	it("starts on Browse with nothing searched, selected, running or announced", function()
		local state = newStore():getState()

		expect(state.tab).toBe("browse")
		expect(state.query).toBe("")
		expect(state.search).toEqual({ status = "idle", results = {} })
		expect(state.installed).toEqual({})
		expect(state.selection).toBe(nil)
		expect(state.detail).toEqual({ status = "idle", versions = {}, realms = {} })
		expect(state.form).toEqual({ realm = "shared", alias = "", errors = {} })
		expect(state.operation).toBe(nil)
		expect(state.notice).toBe(nil)
		expect(typeof(state.onInstallClicked)).toBe("function")
	end)

	it("changes only the key each action names", function()
		local store = newStore()
		local before = store:getState()

		store:dispatch({ type = "setTab", tab = "installed" })
		store:dispatch({ type = "setQuery", query = "signal" })
		store:dispatch({ type = "setSearch", search = { status = "searching", results = {} } })

		local after = store:getState()

		expect(after.tab).toBe("installed")
		expect(after.query).toBe("signal")
		expect(after.search.status).toBe("searching")
		expect(after.installed).toBe(before.installed)
		expect(after.form).toBe(before.form)
	end)

	it("merges form edits and replaces the errors whole", function()
		local store = newStore()

		store:dispatch({ type = "setForm", form = { version = "2.0.3", alias = "Signal", errors = { name = "taken" } } })
		store:dispatch({ type = "setForm", form = { realm = "server", errors = { version = "none match" } } })

		expect(store:getState().form).toEqual({
			version = "2.0.3",
			realm = "server",
			alias = "Signal",
			errors = { version = "none match" },
		})
	end)

	it("starts the detail and form errors afresh whenever the selection changes", function()
		local store = newStore()

		store:dispatch({ type = "setSelection", selection = selection })
		store:dispatch({ type = "setDetail", detail = { status = "done", versions = { "2.0.3" }, realms = {} } })
		store:dispatch({ type = "setForm", form = { alias = "Signal", errors = { name = "taken" } } })
		store:dispatch({ type = "setSelection", selection = nil })

		local state = store:getState()

		expect(state.selection).toBe(nil)
		expect(state.detail).toEqual({ status = "idle", versions = {}, realms = {} })
		expect(state.form.errors).toEqual({})
		expect(state.form.alias).toBe("Signal")
	end)

	it("clears the operation and the notice when given nothing", function()
		local store = newStore()

		store:dispatch({
			type = "setOperation",
			operation = {
				kind = "install",
				target = "result:sleitnick/signal",
				step = "resolving",
				done = 0,
				total = 0,
			},
		})
		store:dispatch({ type = "setNotice", notice = { kind = "installed", message = "Installed Signal 2.0.3" } })
		store:dispatch({ type = "setOperation", operation = nil })
		store:dispatch({ type = "setNotice", notice = nil })

		expect(store:getState().operation).toBe(nil)
		expect(store:getState().notice).toBe(nil)
	end)

	it("installs the callbacks it is given beside the defaults", function()
		local store = newStore()
		local onUndo = function() end

		store:dispatch({ type = "setCallbacks", callbacks = { onUndo = onUndo } })

		expect(store:getState().onUndo).toBe(onUndo)
		expect(typeof(store:getState().onSearchTextUpdated)).toBe("function")
	end)
end)
