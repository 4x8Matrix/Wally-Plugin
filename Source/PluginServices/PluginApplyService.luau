local ScriptEditorService = game:GetService("ScriptEditorService")

local Console = require(script.Parent.Parent.Packages.Console)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local PluginPropertyService = require(script.Parent.PluginPropertyService)
local PluginReflectionService = require(script.Parent.PluginReflectionService)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)

local STUDIO_STRING_LIMIT = 200000

local PluginApplyService = {}

PluginApplyService.Reporter = Console.new(`🖌️ {script.Name}`)

-- seam: a repeated tag is kept once, as AddTag keeps one of each; upgrade trigger: a package whose tags repeat
-- seam: an empty tag is dropped, as AddTag ignores it; upgrade trigger: a package with an empty tag
--[[
	Replaces an instance's tags with `tags`.
]]
function PluginApplyService.ApplyTags(_: PluginApplyService, instance: Instance, tags: { string })
	for _, tag in instance:GetTags() do
		instance:RemoveTag(tag)
	end

	for _, tag in tags do
		instance:AddTag(tag)
	end
end

--[[
	Replaces an instance's attributes with `attributes`.
]]
function PluginApplyService.ApplyAttributes(self: PluginApplyService, instance: Instance, attributes: { [string]: any })
	for name in instance:GetAttributes() do
		self:SetAttribute(instance, name, nil)
	end

	for name, value in attributes do
		self:SetAttribute(instance, name, value)
	end
end

--[[
	Sets one attribute, or warns when Studio will not let a plugin set it: an `RBX` prefix, a name over 100
		characters or holding a space. Studio drops all but the `RBX` ones from Rojo's build too.
]]
function PluginApplyService.SetAttribute(self: PluginApplyService, instance: Instance, name: string, value: any)
	local set, reason = pcall(instance.SetAttribute, instance, name, value)

	if not set then
		self.Reporter:Warn(`Attribute {name} on {instance:GetFullName()} was left out: {reason}`)
	end
end

--[[
	Sets a LocalizationTable's Contents through SetContents, as a plugin cannot assign the property. Contents that
		is not JSON leaves the table empty with a warning, as Studio loads Rojo's build of it (measured).
]]
function PluginApplyService.SetContents(
	self: PluginApplyService,
	localizationTable: LocalizationTable,
	contents: string
)
	local set, reason = pcall(localizationTable.SetContents, localizationTable, contents)

	if not set then
		localizationTable:SetContents("[]")
		self.Reporter:Warn(`{localizationTable:GetFullName()}.Contents was left empty, as Studio loads it: {reason}`)
	end
end

-- seam: UpdateSourceAsync turns a lone CR into LF; upgrade trigger: a package whose long script holds one
--[[
	Sets a script's Source through ScriptEditorService, which takes one of STUDIO_STRING_LIMIT bytes or more where
		assigning it fails (measured up to 2.5 MB on a detached ModuleScript, Script and LocalScript).
]]
function PluginApplyService.UpdateSource(_: PluginApplyService, container: LuaSourceContainer, source: string)
	ScriptEditorService:UpdateSourceAsync(container, function()
		return source
	end)
end

-- seam: a string property set from a plugin stops at its first NUL; upgrade trigger: a package whose strings hold NUL
-- seam: any other string of STUDIO_STRING_LIMIT bytes or more is refused; upgrade trigger: a package holding one
--[[
	Sets resolved properties on an instance, in name order: `Tags` through AddTag and `Attributes` through
		SetAttribute, each replacing what the instance had; a property PluginReflectionService names a setter for
		(LocalizationTable's `Contents`) through that method here; a script's `Source` too long to assign through
		UpdateSource; and PluginPropertyService's `Nil` as nil. A property Studio refuses fails the call, naming it.
]]
function PluginApplyService.Apply(
	self: PluginApplyService,
	instance: Instance,
	properties: { [string]: any }
): Types.BuildResult<nil>
	local names = {}

	for name in properties do
		table.insert(names, name)
	end

	table.sort(names)

	for _, name in names do
		local value = properties[name]
		local property = PluginReflectionService:FindProperty(instance.ClassName, name)
		local setter = if property then property.setter else nil
		local assigned, reason = true, nil

		if name == "Tags" then
			self:ApplyTags(instance, value)
		elseif name == "Attributes" then
			self:ApplyAttributes(instance, value)
		elseif setter then
			self[setter](self, instance, value)
		elseif name == "Source" and instance:IsA("LuaSourceContainer") and #value >= STUDIO_STRING_LIMIT then
			assigned, reason = pcall(self.UpdateSource, self, instance, value)
		else
			assigned, reason = pcall(function()
				instance[name] = if value == PluginPropertyService.Nil then nil else value
			end)
		end

		if not assigned then
			return buildError("", `{instance.ClassName}.{name} could not be set: {reason}`)
		end
	end

	return { ok = true }
end

export type PluginApplyService = typeof(PluginApplyService)

return PluginApplyService
