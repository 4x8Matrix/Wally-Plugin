local ZZLib = require(script.Parent.Parent.Packages.ZZLib)

local Types = require(script.Parent.Parent.PluginUtilities.Types)

local buildError = require(script.Parent.Parent.PluginUtilities.buildError)
local joinPath = require(script.Parent.Parent.PluginUtilities.joinPath)

local VirtualFileSystem = {}

VirtualFileSystem.Interface = {}
VirtualFileSystem.Prototype = {
	Directories = {} :: { [string]: { [string]: true } },
	Files = {} :: { [string]: () -> string },
}

--[[
	Records one zip member or in-memory file: a name ending in `/` is a directory, any other name a file whose
		contents `read` returns, and every directory above it exists too.
]]
function VirtualFileSystem.Prototype.AddEntry(self: VirtualFileSystem, name: string, read: () -> string)
	local isDirectory = string.sub(name, -1) == "/"
	local components = {}
	local parent = ""

	for _, component in string.split(name, "/") do
		if component ~= "" then
			table.insert(components, component)
		end
	end

	for index, component in components do
		local path = joinPath(parent, component)

		self.Directories[parent][component] = true

		if index < #components or isDirectory then
			self.Directories[path] = self.Directories[path] or {}
		else
			self.Files[path] = read
		end

		parent = path
	end
end

--[[
	Lists every member of a zip into the tree, failing instead of throwing when ZZLib cannot list it; a member is
		only decompressed when it is read.
]]
function VirtualFileSystem.Prototype.AddZip(self: VirtualFileSystem, zip: string): Types.BuildResult<nil>
	local listed, reason = pcall(function()
		for _, name, offset, size, packed, crc in ZZLib.files(zip) do
			self:AddEntry(name, function()
				return if packed then ZZLib.unzip(zip, offset, crc) else string.sub(zip, offset, offset + size - 1)
			end)
		end
	end)

	if not listed then
		return buildError("", `the zip could not be read: {self:DescribeFailure(reason)}`)
	end

	return { ok = true, value = nil }
end

--[[
	Turns a `/`-joined path into the path of what it names, as the filesystem resolves it: an empty or `.`
		component stays put and `..` steps up, each needing a directory to stand on. Nothing is named by an
		absolute path, a path that steps above the root, or one that stands on a missing directory or a file.
]]
function VirtualFileSystem.Prototype.Resolve(self: VirtualFileSystem, path: string): string?
	local components = {}

	if string.sub(path, 1, 1) == "/" then
		return
	end

	for _, component in string.split(path, "/") do
		if component ~= "" and component ~= "." and component ~= ".." then
			table.insert(components, component)

			continue
		end

		if not self.Directories[table.concat(components, "/")] then
			return
		end

		if component == ".." and #components == 0 then
			return
		end

		if component == ".." then
			table.remove(components)
		end
	end

	return table.concat(components, "/")
end

--[[
	Whether resolving a path stands on a file, where the filesystem answers "Not a directory" and Rojo 7.7.1 refuses
		the build: a component, empty, `.` and `..` ones included, after one that names a file. A path that first
		meets a missing entry, or leaves the root, does not; it only names nothing.
]]
function VirtualFileSystem.Prototype.RunsThroughFile(self: VirtualFileSystem, path: string): boolean
	local components = {}

	if string.sub(path, 1, 1) == "/" then
		return false
	end

	for _, component in string.split(path, "/") do
		local standing = table.concat(components, "/")

		if self.Files[standing] then
			return true
		end

		if not self.Directories[standing] or (component == ".." and #components == 0) then
			return false
		end

		if component == ".." then
			table.remove(components)
		elseif component ~= "" and component ~= "." then
			table.insert(components, component)
		end
	end

	return false
end

--[[
	Whether a path names a file.
]]
function VirtualFileSystem.Prototype.IsFile(self: VirtualFileSystem, path: string): boolean
	local resolved = self:Resolve(path)

	return if resolved and self.Files[resolved] then true else false
end

--[[
	Whether a path names a directory; `""` is the root.
]]
function VirtualFileSystem.Prototype.IsDirectory(self: VirtualFileSystem, path: string): boolean
	local resolved = self:Resolve(path)

	return if resolved and self.Directories[resolved] then true else false
end

--[[
	The names of a directory's entries, sorted by bytes as Rojo orders children; empty for anything else.
]]
function VirtualFileSystem.Prototype.ListDirectory(self: VirtualFileSystem, path: string): { string }
	local resolved = self:Resolve(path)
	local entries = if resolved then self.Directories[resolved] else nil
	local names = {}

	if not entries then
		return names
	end

	for name in entries do
		table.insert(names, name)
	end

	table.sort(names)

	return names
end

--[[
	Reads a file, failing with the path it was given when nothing readable is there.
]]
function VirtualFileSystem.Prototype.ReadFile(self: VirtualFileSystem, path: string): Types.BuildResult<string>
	local resolved = self:Resolve(path)
	local read = if resolved then self.Files[resolved] else nil

	if not read then
		local message = if resolved and self.Directories[resolved] then "is a directory" else "no such file"

		return buildError(path, message)
	end

	local decompressed, contents = pcall(read)

	if not decompressed then
		return buildError(path, `could not be decompressed: {self:DescribeFailure(contents)}`)
	end

	return { ok = true, value = contents }
end

--[[
	An error caught from ZZLib, without the script and line it was raised at.
]]
function VirtualFileSystem.Prototype.DescribeFailure(_: VirtualFileSystem, reason: any): string
	local description = string.gsub(tostring(reason), "^.-:%d+: ", "")

	return description
end

--[[
	Instantiates a VirtualFileSystem from in-memory files, keyed by `/`-joined path; a key ending in `/` is an
		empty directory and its value is ignored.
]]
function VirtualFileSystem.Interface.fromFiles(files: { [string]: string }): VirtualFileSystem
	local self = setmetatable({
		Directories = { [""] = {} },
		Files = {},
	}, {
		__index = VirtualFileSystem.Prototype,
	})

	for name, contents in files do
		self:AddEntry(name, function()
			return contents
		end)
	end

	return self
end

--[[
	Instantiates a VirtualFileSystem from a zip, failing instead of throwing when the zip cannot be listed.
]]
function VirtualFileSystem.Interface.fromZip(zip: string): Types.BuildResult<VirtualFileSystem>
	local self = VirtualFileSystem.Interface.fromFiles({})
	local added = self:AddZip(zip)

	if not added.ok then
		return added
	end

	return { ok = true, value = self }
end

export type VirtualFileSystem = typeof(VirtualFileSystem.Prototype)

return VirtualFileSystem.Interface
