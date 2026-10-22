# Wally Plugin

<a href="https://github.com/4x8Matrix/Wally-Plugin/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/4x8Matrix/Wally-Plugin?style=plastic&logo=github&labelColor=%232a3036"></a>
<a href="https://github.com/4x8Matrix/Wally-Plugin/actions/workflows/release.yml"><img alt="Release workflow status" src="https://img.shields.io/github/actions/workflow/status/4x8Matrix/Wally-Plugin/release.yml?style=plastic&logo=githubactions&label=release&labelColor=%232a3036"></a>

Wally Plugin is a Roblox Studio plugin that searches the [Wally](https://wally.run) registry and installs packages straight into the open place, laid out the way the Wally CLI lays them out.

## Getting Started

Download `WallyPlugin.rbxm` from the [latest release](https://github.com/4x8Matrix/Wally-Plugin/releases/latest) and drop it into your Studio plugins folder (the Plugins tab, then Plugins Folder). Restart Studio and open Wally from the Plugins tab.

Packages install into `ReplicatedStorage.Packages` for shared code or `ServerStorage.Packages` for the server, and every install can be undone with Studio's Undo.
