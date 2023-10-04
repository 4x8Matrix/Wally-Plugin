local ZZLib = require(script.Parent.Parent.Packages.ZZLib)

local VirtualFileSystem = { }

VirtualFileSystem.Interface = { }
VirtualFileSystem.Prototype = { }

VirtualFileSystem.Prototype.Buffer = ""
VirtualFileSystem.Prototype.FileMap = { }

--[[
	Used in the constructor function to map out the files and their full names from a zip buffer.
]]
function VirtualFileSystem.Prototype.BuildInternalFileMap(self: VirtualFileSystem)
	local virtualZipDirectory = { }

	for _, zipFileFullName in ZZLib.files(self.Buffer) do
		if string.sub(zipFileFullName, -1) == "/" then
			continue
		end

		local zipFileFullNameSplit = string.split(zipFileFullName, "/")
		local headNode = virtualZipDirectory

		for index, directoryName in zipFileFullNameSplit do
			if index == #zipFileFullNameSplit then
				continue
			end

			if not headNode[directoryName] then
				headNode[directoryName] = { }
			end

			headNode = headNode[directoryName]
		end

		local fileName = zipFileFullNameSplit[#zipFileFullNameSplit]

		headNode[fileName] = zipFileFullName
	end

	return virtualZipDirectory
end

--[[
	Navigates to a directory from a path.
]]
function VirtualFileSystem.Prototype.GetDirectoryFromPath(self: VirtualFileSystem, path: string)
	local directorySplit = string.split(path, "/")
	local headNode = self.FileMap

	if path == "" then
		return headNode
	end

	for _, directoryName in directorySplit do
		if directoryName == "" then
			continue
		end

		headNode = headNode[directoryName]
	end

	return headNode
end

--[[
	Read and return the contents of a compressed file inside of the zip buffer
]]
function VirtualFileSystem.Prototype.ReadFileContents(self: VirtualFileSystem, fullFileName: string)
	return ZZLib.unzip(self.Buffer, fullFileName)
end

--[[
	Check to see if a given path is a directory.
]]
function VirtualFileSystem.Prototype.IsDirectory(self: VirtualFileSystem, directory: string)
	local directorySplit = string.split(directory, "/")
	local headNode = self.FileMap

	if directory == "" then
		return true
	end

	for _, directoryName in directorySplit do
		if directoryName == "" then
			continue
		end

		headNode = headNode[directoryName]
	end

	return typeof(headNode) == "table"
end

--[[
	Check to see if a directory inside of the zip buffer has a specific file.
]]
function VirtualFileSystem.Prototype.DirectoryHasFile(self: VirtualFileSystem, directory: string, fileName: string)
	local directoryMap = self:GetDirectoryFromPath(directory)

	return directoryMap[fileName] ~= nil
end

--[[
	Instantiates a new VirtualFileSystem from a zip buffer, or otherwise typed as string.

	A VirtualFileSystem maps out each of the files inside of a compressed zip string, allowing us to unpack and navigate
	the file system.

	For ex:
		- Example.json
		- Folder/Source.lua

	will be translated into:
		- {
			["Example.json"] = "Example.json",
			["Folder"] = {
				["Source"] = "Folder/Source.lua"
			}
		}
]]
function VirtualFileSystem.Interface.fromZip(zipBuffer: string): VirtualFileSystem
	local self = setmetatable({
		Buffer = zipBuffer,
		FileMap = { }
	}, {
		__index = VirtualFileSystem.Prototype
	})

	self.FileMap = self:BuildInternalFileMap()

	return self
end

export type VirtualFileSystem = typeof(VirtualFileSystem.Prototype)

return VirtualFileSystem.Interface