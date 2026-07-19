# Read this before installing Aegis GMS

This is the minimal end-user package for installing Aegis GMS in Roblox Studio.

## Included files

- `AegisGMS_Studio_Package.rbxmx` - the Roblox Studio package
- `READ_ME_FIRST.md` - these installation instructions
- `LICENSE` - the MIT licence

## Installation

1. Make a backup of your experience and test in a private copy first.
2. Drag `AegisGMS_Studio_Package.rbxmx` into Roblox Studio.
3. Expand the imported `AegisGMS_Package` model.
4. Move its `ReplicatedStorage` contents into the real `ReplicatedStorage` service.
5. Move its `ServerScriptService` contents into the real `ServerScriptService` service.
6. Move `AdminFrameworkClient` from the package's
   `StarterPlayer/StarterPlayerScripts` folder into the real
   `StarterPlayerScripts` service.
7. Delete the now-empty imported package model.
8. Open `ReplicatedStorage/AdminFramework/Shared/Config` and configure trusted
   owner user IDs or the Roblox Group rank mapping before publishing.
9. Publish the experience, play-test as an authorised account, and press `F2`
   or use the **Open Aegis** button.

For Studio persistence tests, enable **Game Settings -> Security -> Enable Studio
Access to API Services**. DataStore, MessagingService, TeleportService, and
MemoryStore features require a published experience for meaningful testing.

## Full source and documentation

The editable Rojo source, security notes, troubleshooting, examples, and action
reference are available at:

https://github.com/DarkMartha/Project-Aegis-GMS
