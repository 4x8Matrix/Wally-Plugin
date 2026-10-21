local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TestService = game:GetService("TestService")

-- selene: allow(global_usage)
_G.NOCOLOR = true

local Jest = require(ReplicatedStorage.Packages.Jest)

--[[
	Runs every spec under `ReplicatedStorage.Tests` and returns the totals line. It is called from edit mode through
		`execute_luau`: Jest reads each module's `Source`, and the specs write link sources, which a playtest script is
		not allowed to do.
]]
return function(): string
	local status, result = Jest.runCLI(ReplicatedStorage.Tests, {
		ci = false,
		verbose = false,
		testMatch = { "**/*.spec" }
	}, {
		ReplicatedStorage.Tests
	}):awaitStatus()
	local totals = if status == "Resolved" then result.results else nil
	local summary = if totals
		then `JEST RESULT {totals.numPassedTests} passed, {totals.numFailedTests} failed, {totals.numFailedTestSuites} failed suites`
		else `JEST RESULT rejected: {tostring(result)}`

	TestService:Message(summary)

	return summary
end
