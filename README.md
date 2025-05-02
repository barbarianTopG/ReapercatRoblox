# Watchcat for Roblox
Watchcat is an advanced level anti-cheat for movement on Roblox.
This anti-chat includes:
- WalkSpeed Speed Checks
- Velocity Speed Checks
- CFrame Speed Checks
- Position Float Checks
- Velocity Float Checks
- Position Unexpected Action Checks
- Velocity Unexpected Action Checks
- CFrame Unexpected Action Checks

- Easy way to teleport & do advanced movement without flagging the anti-cheat
# How to install
1. Make a new folder called "Watchcat" in ServerScriptService
2. Made a new script called "Core"
3. Copy "Core.lua" from this GitHub, and paste it into the script
4. Make a new folder called "Watchcat" in ReplicatedStorage
5. Add 2 new RemoteEvents inside that folder: FlagEvent, DetectionEvent
### NOTE: This part is for detecting WalkSpeed, there is 2 methods
## Simple LocalScript
- This is the most detectable but easiest way to add the detection
1. Make a new LocalScript in Workspace, ReplicatedStorage, StarterCharacterScripts or StarterPlayerScripts
2. In that script, paste the following:
```lua
task.spawn(function()
	local playersService = game:GetService("Players")
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local lplr = playersService.LocalPlayer

	lplr.Character.Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		replicatedStorage:WaitForChild("Watchcat").DetectionEvent:FireServer(lplr.Character.Humanoid.WalkSpeed)
	end)
end)
```
## Hidden
- This is the least detectable, but harder way to add the detection
1. Find a working LocalScript, and paste this where it will run upon the Character being created:
```lua
task.spawn(function()
	local playersService = game:GetService("Players")
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local lplr = playersService.LocalPlayer

	lplr.Character.Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		replicatedStorage:WaitForChild("Watchcat").DetectionEvent:FireServer(lplr.Character.Humanoid.WalkSpeed)
	end)
end)
```
# Flag & Detection Alerts
Now that we have those RemoteEvents, we can put them to use. You can also add checks for the player if they are staff, or a different rank depending on your game.
1. Create a LocalScript in PlayerScripts -> StarterPlayerScripts
2. In that script, paste the following:
```lua
local replicatedStorage = game:GetService("ReplicatedStorage")
local textChatService = game:GetService("TextChatService")

-- Detection
replicatedStorage.Watchnoob.DetectionEvent.OnClientEvent:Connect(function(plr)
	textChatService.TextChannels.RBXGeneral:DisplaySystemMessage("[WATCHCAT CHEAT DETECTION] A player has been removed from your game for exploiting.")
end)

-- Flags
replicatedStorage.Watchnoob.FlagEvent.OnClientEvent:Connect(function(plr: Player, detection)
	textChatService.TextChannels.RBXGeneral:DisplaySystemMessage(plr.Name.." has flagged "..detection)
end)
```
