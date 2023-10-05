local RunService = game:GetService("RunService")

if not plugin then
	return warn(`Plugin Runtime not running, capable environment not avaliable`)
end

if RunService:IsRunning() then
	return
end

local PLUGIN_INIT_LIFECYCLE_NAME = "OnInit"
local PLUGIN_START_LIFECYCLE_NAME = "OnStart"

local PLUGIN_STOP_LIFECYCLE_NAME = "OnStop"

local PLUGIN_LOG_SCHEMA = "[%s][%s] :: %s"

local Loader = require(script.Parent.Packages.Loader)
local Console = require(script.Parent.Packages.Console)

local PluginContext = require(script.Parent.PluginContext)

local runtimeClockSnapshot = os.clock()
local runtimeReporter = Console.new(`🚀 {script.Name}`)

local branch = script.Parent:GetAttribute("Branch")
local commit = script.Parent:GetAttribute("Commit")

--[[
	Disable the ability to log on the production version of the plugin.
]]
if branch == "master" then
	Console.setGlobalLogLevel(Console.LogLevel.Warn)
else
	Console.setGlobalLogLevel(Console.LogLevel.Debug)
	Console.setGlobalSchema(PLUGIN_LOG_SCHEMA)
end

xpcall(function()
	--[[
		In order for all of our Services to access the 'plugin' instance, we refer to the PluginContext file which 
			houses the reference to our plugin instance.
	]]

	PluginContext.Plugin = plugin
	PluginContext.Plugin.Name = `Plugin<"Wally-Plugin">`

	Loader.SpawnAll(Loader.LoadChildren(script.Parent.PluginServices), PLUGIN_INIT_LIFECYCLE_NAME)
	Loader.SpawnAll(Loader.LoadChildren(script.Parent.PluginServices), PLUGIN_START_LIFECYCLE_NAME)

	PluginContext.Plugin.Unloading:Once(function()
		Loader.SpawnAll(Loader.LoadChildren(script.Parent.PluginServices), PLUGIN_STOP_LIFECYCLE_NAME)
	end)

	runtimeReporter:Log(`Loaded all Plugin Services! ({os.clock() - runtimeClockSnapshot}ms)`)

	runtimeReporter:Log(`Plugin Commit SHA: {commit}`)
	runtimeReporter:Log(`Plugin Branch: {branch}`)

	PluginContext.Plugin.Unloading:Once(function()
		task.defer(function()
			runtimeReporter:Log(`Exited Plugin! See you around 👋`)
		end)
	end)
end, function(exceptionMessage)
	task.spawn(function()
		runtimeReporter:Critical(exceptionMessage)
	end)
end)