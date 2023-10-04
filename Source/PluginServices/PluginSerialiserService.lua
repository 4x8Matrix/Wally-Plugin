local HttpService = game:GetService("HttpService")

local Console = require(script.Parent.Parent.Packages.Console)

local VirtualFileSystem = require(script.Parent.Parent.PluginClasses.VirtualFileSystem)

local PATH_SYMBOL = "$path"
local CLASS_SYMBOL = "$className"
local PROP_SYMBOL = "$properties"

local PluginDownloadService = { }

PluginDownloadService.Reporter = Console.new(`🍃 {script.Name}`)

function PluginDownloadService.ParseNode(_: PluginDownloadService, virtualFileSystem: VirtualFileSystem.VirtualFileSystem, nodePath: string)
	if string.sub(nodePath, -10) == "client.lua" or string.sub(nodePath, -11) == "client.luau" then
		local Node = script.Parent.Parent.PluginBlobs.TemplateRootClient:Clone()

		Node.Source = virtualFileSystem:ReadFileContents(nodePath)

		return Node
	elseif string.sub(nodePath, -10) == "server.lua" or string.sub(nodePath, -11) == "server.luau" then
		local Node = script.Parent.Parent.PluginBlobs.TemplateRootServer:Clone()

		Node.Source = virtualFileSystem:ReadFileContents(nodePath)

		return Node
	elseif string.sub(nodePath, -3) == "lua" or string.sub(nodePath, -4) == "luau" then
		local Node = script.Parent.Parent.PluginBlobs.TemplateRootModule:Clone()

		Node.Source = virtualFileSystem:ReadFileContents(nodePath)

		return Node
	elseif virtualFileSystem:IsDirectory(nodePath) then
		return Instance.new("Folder")
	end

	return
end

function PluginDownloadService.ParseHeadNode(self: PluginDownloadService, virtualFileSystem: VirtualFileSystem.VirtualFileSystem, projectPath: string)
	if virtualFileSystem:IsDirectory(projectPath) then
		if virtualFileSystem:DirectoryHasFile(projectPath, "init.lua") then
			return self:ParseNode(virtualFileSystem, `{projectPath}init.lua`), "init.lua"
		elseif virtualFileSystem:DirectoryHasFile(projectPath, "init.client.lua") then
			return self:ParseNode(virtualFileSystem, `{projectPath}init.client.lua`), "init.client.lua"
		elseif virtualFileSystem:DirectoryHasFile(projectPath, "init.server.lua") then
			return self:ParseNode(virtualFileSystem, `{projectPath}init.server.lua`), "init.server.lua"
		elseif virtualFileSystem:DirectoryHasFile(projectPath, "init.luau") then
			return self:ParseNode(virtualFileSystem, `{projectPath}init.luau`), "init.luau"
		elseif virtualFileSystem:DirectoryHasFile(projectPath, "init.client.luau") then
			return self:ParseNode(virtualFileSystem, `{projectPath}init.client.luau`), "init.client.luau"
		elseif virtualFileSystem:DirectoryHasFile(projectPath, "init.server.luau") then
			return self:ParseNode(virtualFileSystem, `{projectPath}init.server.luau`), "init.server.luau"
		else
			return self:ParseNode(virtualFileSystem, `{projectPath}`), nil
		end
	else
		return self:ParseNode(virtualFileSystem, projectPath), "*"
	end
end

function PluginDownloadService.ParseVirtualFileSystemDirectory(self: PluginDownloadService, virtualFileSystem: VirtualFileSystem.VirtualFileSystem, projectPath: string)
	if string.sub(projectPath, 1, 2) == "./" then
		projectPath = string.sub(projectPath, 3, #projectPath)
	elseif string.sub(projectPath, 1, 2) == "/" then
		projectPath = string.sub(projectPath, 2, #projectPath)
	elseif string.sub(projectPath, #projectPath, #projectPath) == "/" then
		projectPath = string.sub(projectPath, 1, -2)
	end

	if projectPath ~= "" then
		if string.sub(projectPath, -3) ~= "lua" and string.sub(projectPath, -4) ~= "luau" then
			projectPath = projectPath ~= "" and `{projectPath}/` or projectPath
		end
	end

	local headNode, headNodeName = self:ParseHeadNode(virtualFileSystem, projectPath)

	if headNodeName == "*" then
		return headNode
	else
		for nodeName in virtualFileSystem:GetDirectoryFromPath(projectPath) do
			if nodeName == headNodeName then
				continue
			end

			if virtualFileSystem:IsDirectory(`{projectPath}{nodeName}`) then
				local node = self:ParseVirtualFileSystemDirectory(virtualFileSystem, `{projectPath}{nodeName}`)

				node.Parent = headNode
				node.Name = nodeName
			else
				local node = self:ParseNode(virtualFileSystem, `{projectPath}{nodeName}`)

				if node then
					nodeName = string.gsub(nodeName, ".luau", "")
					nodeName = string.gsub(nodeName, ".lua", "")

					node.Parent = headNode
					node.Name = nodeName
				end
			end
		end
	end

	return headNode
end

function PluginDownloadService.SerialiseRojoProjectTree(self: PluginDownloadService, virtualFileSystem: VirtualFileSystem.VirtualFileSystem, projectTree: { [any]: any })
	local headNode

	if projectTree[PATH_SYMBOL] then
		headNode = self:ParseVirtualFileSystemDirectory(virtualFileSystem, `{projectTree[PATH_SYMBOL]}`)
	elseif projectTree[CLASS_SYMBOL] then
		headNode = Instance.new(projectTree[CLASS_SYMBOL])
	else
		error(`Failed to parse project tree`)
	end

	if projectTree[PROP_SYMBOL] then
		if projectTree[PROP_SYMBOL].Attributes then
			error(`Attributes aren't supported yet!`)
		end

		for propertyName, propertyValue in projectTree[PROP_SYMBOL] do
			headNode[propertyName] = propertyValue
		end
	end

	for key, value in projectTree do
		if string.sub(key, 1, 1) == "$" then
			continue
		end

		local keyNode = self:SerialiseRojoProjectTree(virtualFileSystem, value)
		
		keyNode.Name = key
		keyNode.Parent = headNode
	end

	return headNode
end

function PluginDownloadService.SerialiseZipIntoRobloxInstances(self: PluginDownloadService, rawZipBuffer: string)
	local virtualFileSystem = VirtualFileSystem.fromZip(rawZipBuffer)

	if virtualFileSystem:DirectoryHasFile("", "default.project.json") then
		local projectFileContent = virtualFileSystem:ReadFileContents("default.project.json")
		local projectFileJson = HttpService:JSONDecode(projectFileContent)

		local projectName = projectFileJson.name
		local projectTree = projectFileJson.tree

		local headNode = self:SerialiseRojoProjectTree(virtualFileSystem, projectTree)

		headNode.Name = projectName

		return headNode
	else
		local headNode = self:ParseVirtualFileSystemDirectory(virtualFileSystem, "")

		return headNode
	end
end

export type PluginDownloadService = typeof(PluginDownloadService)

return PluginDownloadService