local Types = require(script.Parent.Types)

local buildError = require(script.Parent.buildError)
local decodeCsv = require(script.Parent.decodeCsv)
local decodeJsonc = require(script.Parent.decodeJsonc)
local decodeToml = require(script.Parent.decodeToml)
local decodeYaml = require(script.Parent.decodeYaml)
local encodeLuauValue = require(script.Parent.encodeLuauValue)

local SCRIPTS = {
	serverScript = { className = "Script", runContext = Enum.RunContext.Legacy },
	clientScript = { className = "LocalScript" },
	moduleScript = { className = "ModuleScript" },
	pluginScript = { className = "Script", runContext = Enum.RunContext.Plugin },
	legacyServerScript = { className = "Script", runContext = Enum.RunContext.Legacy },
	legacyClientScript = { className = "LocalScript" },
	runContextServerScript = { className = "Script", runContext = Enum.RunContext.Server },
	runContextClientScript = { className = "Script", runContext = Enum.RunContext.Client },
}
local RUN_CONTEXT_SCRIPTS = {
	serverScript = { className = "Script", runContext = Enum.RunContext.Server },
	clientScript = { className = "Script", runContext = Enum.RunContext.Client },
}
local DECODERS = { csv = decodeCsv, json = decodeJsonc, toml = decodeToml, yaml = decodeYaml }

local function decoded(className: string, properties: { [string]: any }): Types.BuildResult<Types.DecodedFile>
	return { ok = true, value = { className = className, properties = properties } }
end

--[[
	Decodes what a script, text, CSV or data file becomes before its meta files apply, by the sync rule `use`
		that picked it: a script's class and RunContext by its kind and `emitLegacyScripts` (R1.3) with its text as
		`Source`, CRLF turned into LF; a text file as a StringValue holding its text untouched (R1.8); a CSV file as
		a LocalizationTable (R1.9); a JSON, TOML or YAML file as a ModuleScript returning its value (R1.5 to R1.7).
		Scripts and text must be UTF-8, and each decoder refuses in Rojo's words. The error names no path; the
		caller adds the file it read.
]]
return function(contents: string, use: string, emitLegacyScripts: boolean): Types.BuildResult<Types.DecodedFile>
	local scriptKind = if emitLegacyScripts then SCRIPTS[use] else RUN_CONTEXT_SCRIPTS[use] or SCRIPTS[use]
	local malformed = if use == "json" then "File contains malformed JSON: " else ""

	if (scriptKind or use == "text") and not utf8.len(contents) then
		return buildError("", "File was not valid UTF-8")
	end

	if scriptKind then
		local source = string.gsub(contents, "\r\n", "\n")

		return decoded(scriptKind.className, { Source = source, RunContext = scriptKind.runContext })
	end

	if use == "text" then
		return decoded("StringValue", { Value = contents })
	end

	local value = DECODERS[use](contents)

	if not value.ok then
		return buildError("", `{malformed}{value.error.message}`)
	end

	if use == "csv" then
		return decoded("LocalizationTable", { Contents = value.value })
	end

	return decoded("ModuleScript", { Source = encodeLuauValue(value.value) })
end
