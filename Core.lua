local PlayersService = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local Reapercat = {}
Reapercat.Remotes = {
	Flag = ReplicatedStorage:WaitForChild("Reapercat").FlagEvent,
}
Reapercat.Config = {
	Kick = true,
	ExemptTags = {},
	Checks = {
		Speed = {
			Enabled = true,
			WalkSpeed = 16,
			Velocity = 360,
			CFrame = 18,
			Interval = 0.975,
			MaxViolations = 100
		},
		Float = {
			Enabled = true,
			Velocity = 60,
			Safety = 1.4,
			MaxViolations = 5
		},
		UnexpectedActions = {
			Enabled = true,
			MaxHeight = 10,
			MaxVelocity = 60,
			MaxCFrame = 40,
			MaxViolations = 30
		},
		Noclip = {
			Enabled = true,
			MaxViolations = 10
		}
	}
}
Reapercat.Players = {
	_data = {},
	Add = function(self, player)
		self._data[player] = {
			Violations = {
				Speed = 0,
				Float = 0,
				UnexpectedActions = 0,
				Noclip = 0
			},
			LastPosition = nil,
			LastOnGroundTime = tick(),
			LastCFrame = nil,
			Exceptions = {},
			Character = nil,
			Humanoid = nil,
			HumanoidRootPart = nil
		}
	end,
	Get = function(self, player)
		return self._data[player]
	end,
	Remove = function(self, player)
		self._data[player] = nil
	end,
	SetException = function(self, player, checkType, duration)
		local data = self:Get(player)
		if data then
			data.Exceptions[checkType] = tick() + duration
		end
	end,
	IsExcepted = function(self, player, checkType)
		local data = self:Get(player)
		if not data or not data.Exceptions[checkType] then
			return false
		end;
		return tick() < data.Exceptions[checkType]
	end
}
local function isPartExempt(part)
	if not part then
		return false
	end;
	for _, tag in ipairs(Reapercat.Config.ExemptTags) do
		if CollectionService:HasTag(part, tag) then
			return true
		end
	end;
	return false
end;
local function isOnGround(playerData)
	local char = playerData.Character;
	if not char or not playerData.HumanoidRootPart then
		return false
	end;
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude;
	params.FilterDescendantsInstances = {
		char
	}
	local origin = playerData.HumanoidRootPart.Position;
	local downVector = Vector3.new(0, -5, 0)
	local result = Workspace:Raycast(origin, downVector, params)
	return result and result.Instance and not result.Instance.IsA("TrussPart")
end;
local function isInWater(playerData)
	local hrp = playerData.HumanoidRootPart;
	if not hrp then
		return false
	end;
	local region = Region3.new(hrp.Position - Vector3.new(1, 1, 1), hrp.Position + Vector3.new(1, 1, 1))
	local materials = Workspace.Terrain:ReadVoxels(region:ExpandToGrid(4), 4)
	for x = 1, materials.Size.X do
		for y = 1, materials.Size.Y do
			for z = 1, materials.Size.Z do
				if materials[x][y][z] == Enum.Material.Water then
					return true
				end
			end
		end
	end;
	return false
end;
local function isOnLadder(playerData)
	local hum = playerData.Humanoid;
	return hum and hum:GetState() == Enum.HumanoidStateType.Climbing
end;
local function punish(player, reason)
	player:Kick(string.format("\n\nReapercat\n\nYou have been removed from the game for: %s.", reason))
end;
local function runChecks(player, playerData, deltaTime)
	if not playerData or not playerData.Character or not playerData.Humanoid or not playerData.HumanoidRootPart then
		return
	end;
	local config = Reapercat.Config;
	local hrp = playerData.HumanoidRootPart;
	local lastCFrame = playerData.LastCFrame or hrp.CFrame;
	if isOnGround(playerData) or isInWater(playerData) or isOnLadder(playerData) then
		playerData.LastOnGroundTime = tick()
	end;
	if config.Checks.Speed.Enabled and not Reapercat.Players:IsExcepted(player, "Speed") then
		local currentPos = hrp.Position;
		local lastPos = playerData.LastPosition or currentPos;
		local displacement = (Vector3.new(currentPos.X, 0, currentPos.Z) - Vector3.new(lastPos.X, 0, lastPos.Z)).Magnitude;
		local speed = displacement / deltaTime;
		if speed > config.Checks.Speed.WalkSpeed + 2 then
			playerData.Violations.Speed = playerData.Violations.Speed + (speed - config.Checks.Speed.WalkSpeed) / 5;
			Reapercat.Remotes.Flag:FireAllClients(player, string.format("Speed (%.2f)", speed))
		else
			playerData.Violations.Speed = math.max(0, playerData.Violations.Speed - 1)
		end;
		playerData.LastPosition = currentPos
	end;
	if config.Checks.Float.Enabled and not Reapercat.Players:IsExcepted(player, "Float") then
		local airTime = tick() - playerData.LastOnGroundTime;
		if airTime > config.Checks.Float.Safety then
			local verticalVelocity = hrp.AssemblyLinearVelocity.Y;
			if verticalVelocity > -config.Checks.Float.Velocity then
				playerData.Violations.Float = playerData.Violations.Float + 1;
				Reapercat.Remotes.Flag:FireAllClients(player, string.format("Float (AirTime: %.2f, VelY: %.2f)", airTime, verticalVelocity))
				hrp:SetNetworkOwner(nil)
				hrp.CFrame = lastCFrame;
				task.delay(1, function()
					if hrp and player then
						hrp:SetNetworkOwner(player)
					end
				end)
			end
		else
			playerData.Violations.Float = math.max(0, playerData.Violations.Float - 1)
		end
	end;
	if config.Checks.Noclip.Enabled and not Reapercat.Players:IsExcepted(player, "Noclip") then
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Exclude;
		overlapParams.FilterDescendantsInstances = {
			playerData.Character
		}
		local partsInBody = Workspace:GetPartsInPart(hrp, overlapParams)
		local isClipping = false;
		for _, part in ipairs(partsInBody) do
			if part.CanCollide and not isPartExempt(part) then
				isClipping = true;
				break
			end
		end;
		if isClipping then
			playerData.Violations.Noclip = playerData.Violations.Noclip + 1;
			Reapercat.Remotes.Flag:FireAllClients(player, "Noclip")
			hrp.CFrame = lastCFrame
		else
			playerData.Violations.Noclip = math.max(0, playerData.Violations.Noclip - 1)
		end
	end;
	playerData.LastCFrame = hrp.CFrame;
	if playerData.Violations.Speed > config.Checks.Speed.MaxViolations then
		punish(player, "Excessive Speed")
	elseif playerData.Violations.Float > config.Checks.Float.MaxViolations then
		punish(player, "Flying or Floating")
	elseif playerData.Violations.Noclip > config.Checks.Noclip.MaxViolations then
		punish(player, "Clipping through walls")
	end
end;
local function onCharacterAdded(player, character)
	local playerData = Reapercat.Players:Get(player)
	if not playerData then
		return
	end;
	playerData.Character = character;
	playerData.Humanoid = character:WaitForChild("Humanoid")
	playerData.HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
	playerData.LastPosition = playerData.HumanoidRootPart.Position;
	playerData.LastCFrame = playerData.HumanoidRootPart.CFrame;
	playerData.LastOnGroundTime = tick()
end;
local function onPlayerAdded(player)
	Reapercat.Players:Add(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end;
PlayersService.PlayerAdded:Connect(onPlayerAdded)
PlayersService.PlayerRemoving:Connect(function(player)
	Reapercat.Players:Remove(player)
end)
for _, player in ipairs(PlayersService:GetPlayers()) do
	onPlayerAdded(player)
end;
RunService.Heartbeat:Connect(function(deltaTime)
	for player, playerData in pairs(Reapercat.Players._data) do
		if player and playerData then
			runChecks(player, playerData, deltaTime)
		end
	end
end)
return Reapercat
