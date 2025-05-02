local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local remotes = {
	Flag = replicatedStorage:WaitForChild("Watchcat").FlagEvent,
	Detection = replicatedStorage:WaitForChild("Watchcat").DetectionEvent
}

-- no, its serverside only
shared.Watchcat = {
	Functions = {
		Teleport = function(plr: Player, pos: CFrame)
			plr:SetAttribute("SpeedException", tick() + 1)
			plr:SetAttribute("UnActException", tick() + 1)
			task.wait()
			plr.Character:PivotTo(pos)
		end,
		SetException = function(plr: Player, time: number)
			plr:SetAttribute("Exception", tick() + time)
		end,
		SetCheckException = function(check: string, plr: Player, time: number)
			plr:SetAttribute(check.."Exception", tick() + time)
		end
	},
	Config = {
		Kick = false,
		Speed = {
			Checks = {
				A = true, -- WalkSpeed
				B = true, -- Velocity
				C = true -- CFrame
			},
			WalkSpeed = 16,
			Velocity = 360,
			CFrame = 17,
			Interval = 0.975,
			MaxViolations = 100
		},
		Float = {
			Checks = {
				A = true -- Velocity
			},
			Velocity = 60,
			Safety = 2,
			MaxViolations = 50
		},
		UnexpectedActions = {
			Checks = {
				A = true,
				B = true,
				C = true
			},
			MaxHeight = 10,
			MaxVelocity = 60,
			MaxCFrame = 25,
			MaxViolations = 30
		}
	}
}

local function getConfiguration()
	return shared.Watchcat.Config
end

local Connections = {} -- why? don't ask
function Connections.new(connection: RBXScriptConnection)
	table.insert(Connections, connection)
	local conn = {}
	function conn:End()
		connection:Disconnect()
		for i, v in Connections do
			if v == connection then
				table.remove(Connections, i)
			end
		end
	end
	return conn
end

local function getPlayerException(plr: Player)
	if plr:GetAttribute("Exception") - tick() <= 0 then
		return 0
	end
	return plr:GetAttribute("Exception") - tick()
end

local function getPlayerCheckException(check: string, plr: Player)
	if plr:GetAttribute(check.."Exception") - tick() <= 0 then
		return 0
	end
	return plr:GetAttribute(check.."Exception") - tick()
end

local function setPlayerException(plr: Player, time: number, add)
	plr:SetAttribute("Exception", tick() + time + (add and getPlayerException(plr) or 0))
end

local function setPlayerCheckException(check: string, plr: Player, time: number, add)
	plr:SetAttribute(check.."Exception", tick() + time + (add and getPlayerCheckException(check, plr) or 0))
end

local function isOnGround(plr: Player)
	local char = plr.Character
	if not char then return end
	local hrp: Part = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local rays = {}
	for i = 0, 5 do
		table.insert(rays, workspace:Raycast(hrp.Position, Vector3.new(
			i == 1 and 2 or i == 3 and -2 or 0,
			-7,
			i == 2 and 2 or i == 4 and -2 or 0
		), params))
	end
	for i, v: RaycastResult in rays do
		if v.Instance then
			return true
		end
	end
	return false
end


local function isInWater(plr: Player)
	local char = plr.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local TERRAIN_CHECK_SIZE = Vector3.new(1, 1, 1)
	local TERRAIN_CHECK_RESOLUTION = 4

	local regionCenter = hrp.Position - Vector3.new(0, TERRAIN_CHECK_SIZE.Y / 2, 0)
	local regionMin = regionCenter - TERRAIN_CHECK_SIZE / 2
	local regionMax = regionCenter + TERRAIN_CHECK_SIZE / 2

	local region = Region3.new(regionMin, regionMax):ExpandToGrid(TERRAIN_CHECK_RESOLUTION)
	local materials, occupancies = workspace.Terrain:ReadVoxels(region, TERRAIN_CHECK_RESOLUTION)
	if materials then
		for x = 1, materials.Size.X do
			for y = 1, materials.Size.Y do
				for z = 1, materials.Size.Z do
					if materials[x][y][z] == Enum.Material.Water then
						return true
					end
				end
			end
		end
	end

	return false
end

local function isOnLadder(plr: Player)
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	local hrp: Part = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local rays = {}
	for i = 0, 5 do
		table.insert(rays, workspace:Raycast(hrp.Position, Vector3.new(
			i == 1 and 5 or i == 3 and -5 or 0,
			0,
			i == 2 and 5 or i == 4 and -5 or 0
			), params))
	end
	
	local isOnTruss
	for i, v: RaycastResult in rays do
		if v.Instance and v.Instance.ClassName == "TrussPart" then
			isOnTruss = true
		end
	end

	return hum:GetState() == Enum.HumanoidStateType.Climbing and isOnTruss
end

Connections.new(remotes.Detection.OnServerEvent:Connect(function(plr, speed)
	local config = getConfiguration()
	if getPlayerException(plr) == 0 and getPlayerCheckException("Speed", plr) == 0 and config.Speed.Checks.A and speed > config.Speed.WalkSpeed then
		remotes.Flag:FireAllClients(plr, "Speed A")
		remotes.Detection:FireAllClients(plr)
		if config.Kick then plr:Kick("\n\nWatchcat CHEAT DETECTION\n\nYou have been removed from the game due to continuos cheating and exploiting.") end
		plr.Character:BreakJoints()
	end
end))

Connections.new(playersService.PlayerAdded:Connect(function(plr)
	local charAddedConn
	setPlayerException(plr, 0.05)
	for i, v in {"Speed", "Float", "UnAct"} do
		setPlayerCheckException(v, plr, 0.05)
	end
	charAddedConn = Connections.new(plr.CharacterAdded:Connect(function(char)
		local vl = {
			Speed = 0,
			Float = 0,
			UnexpectedActions = 0
		}
		setPlayerException(plr, 0.05, true)
		
		if playersService:GetPlayerFromCharacter(char) == nil then charAddedConn:End() return end
		local hum: Humanoid = char:WaitForChild("Humanoid")
		local hrp: Part = char:WaitForChild("HumanoidRootPart")
		
		local lastCF = hrp.CFrame
		local lastGroundCF = hrp.CFrame
		local remainingAirTime = 0
		local checksLoop
		checksLoop = runService.Heartbeat:Connect(function(delta)
			if playersService:GetPlayerFromCharacter(char) == nil or char == nil then checksLoop:Disconnect() end
			if getPlayerException(plr) > 0 then
				lastCF = hrp.CFrame
			else
				local config = getConfiguration()
				if vl.Speed > config.Speed.MaxViolations or 
						vl.Float > config.Float.MaxViolations or
						vl.UnexpectedActions > config.UnexpectedActions.MaxViolations	
						then
					remotes.Detection:FireAllClients(plr)
					if config.Kick then plr:Kick("\nWatchcat CHEAT DETECTION\n\nYou have been removed from the game due to continuos cheating and exploiting.") end
					vl.Speed = -math.huge
					vl.Float = -math.huge
					vl.UnexpectedActions = -math.huge
					plr.Character:BreakJoints()
					return
				end
				
				-- UNEXPECTED ACTIONS CHECKS
				for i, check in config.UnexpectedActions.Checks do
					if check and getPlayerCheckException("UnAct", plr) <= 0 then
						if i == "A" then
							if hrp.CFrame.Y - lastCF.Y > config.UnexpectedActions.MaxHeight then
								vl.UnexpectedActions += 1 + math.random() * ((lastCF.Y - lastGroundCF.Y) / 3) + 1
								hrp.CFrame = lastCF
								remotes.Flag:FireAllClients(plr, "Unexpected Actions A ("..lastCF.Y - lastGroundCF.Y..")")
								task.spawn(function()
									hrp:SetNetworkOwner(nil)
									task.wait(0.7)
									hrp:SetNetworkOwner(plr)
								end)
							end
						elseif i == "B" then
							if hrp.Velocity.Y > config.UnexpectedActions.MaxVelocity then
								vl.UnexpectedActions += 1 + math.random() * ((hrp.Velocity.Y) / 3) + 1
								hrp.CFrame = lastCF
								remotes.Flag:FireAllClients(plr, "Unexpected Actions B ("..hrp.Velocity.Y..")")
								task.spawn(function()
									hrp:SetNetworkOwner(nil)
									task.wait(0.7)
									hrp:SetNetworkOwner(plr)
								end)
							end
						elseif i == "C" then
							task.spawn(function()
								local sps
								local oldpos = hrp.Position.Y
								task.wait(config.Speed.Interval)
								if getPlayerException(plr) > 0 or getPlayerCheckException("UnAct", plr) > 0 then return end
								local newpos = hrp.Position.Y
								sps = newpos - oldpos
								if sps > config.UnexpectedActions.MaxCFrame + (isInWater(plr) and 10 or 0) then
									vl.Speed += 1 + math.random() * ((sps - config.UnexpectedActions.MaxCFrame) / 3) + 1
									hrp.CFrame = lastCF
									remotes.Flag:FireAllClients(plr, "Unexpected Actions C ("..sps..")")
									task.spawn(function()
										hrp:SetNetworkOwner(nil)
										task.wait(0.7)
										hrp:SetNetworkOwner(plr)
									end)
								end
							end)
						end
					end
				end

				-- SPEED CHECKS
				local ping = plr:GetNetworkPing() * 2 * 1000
				local pingBonus = -(1 * (ping / 500) - 1)
				for i, check in config.Speed.Checks do
					if check and getPlayerCheckException("Speed", plr) <= 0 then
						if i == "B" then -- Velocity
							local velo = math.max(hrp.Velocity.X, hrp.Velocity.Z) * 0.95
							if velo > config.Speed.WalkSpeed + pingBonus + 1.7 then
								vl.Speed += 1 + math.random() * ((velo - config.Speed.WalkSpeed + pingBonus) / 3) + 1
								hrp.CFrame = lastCF
								remotes.Flag:FireAllClients(plr, "Speed B ("..velo..")")
								task.spawn(function()
									hrp:SetNetworkOwner(nil)
									task.wait(0.7)
									hrp:SetNetworkOwner(plr)
								end)
							end
						elseif i == "C" then -- CFrame
							task.spawn(function()
								local sps
								local oldpos = hrp.Position
								task.wait(config.Speed.Interval)
								if getPlayerException(plr) > 0 or getPlayerCheckException("Speed", plr) > 0 then return end
								local newpos = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
								sps = math.floor((newpos - Vector3.new(oldpos.X, 0, oldpos.Z)).magnitude)
								if sps > config.Speed.CFrame + pingBonus then
									vl.Speed += 1 + math.random() * ((sps - config.Speed.WalkSpeed + pingBonus) / 3) + 1
									hrp.CFrame = lastCF
									remotes.Flag:FireAllClients(plr, "Speed C ("..sps..")")
									task.spawn(function()
										hrp:SetNetworkOwner(nil)
										task.wait(0.7)
										hrp:SetNetworkOwner(plr)
									end)
								end
							end)
						end
					end
				end

				if (isOnGround(plr) or isInWater(plr) or isOnLadder(plr)) and hrp:GetNetworkOwner() == plr then
					remainingAirTime = tick() + config.Float.Safety
					lastGroundCF = hrp.CFrame
				end

				-- FLOAT CHECKS
				for i, check in config.Float.Checks do
					if check and not isOnGround(plr) and not isInWater(plr) and not isOnLadder(plr) and getPlayerCheckException("Float", plr) <= 0 then
						if i == "A" then
							if remainingAirTime - tick() < 0.9 and (hrp.Velocity.Y >= -15 and hrp.Position.Y >= lastGroundCF.Y) then
								vl.Float += 1 + math.random() * (hrp.Velocity.Y / 3) + 1
								hrp.CFrame = lastCF
								remotes.Flag:FireAllClients(plr, "Float A ("..hrp.Velocity.Y..")")
								task.spawn(function()
									hrp:SetNetworkOwner(nil)
									task.wait(0.7)
									hrp:SetNetworkOwner(plr)
								end)
								return
							end
							if remainingAirTime - tick() < 0.5 and hrp.Velocity.Y >= -config.Float.Velocity then
								vl.Float += 1 + math.random() * (hrp.Velocity.Y / 3) + 1
								hrp.CFrame = lastCF
								remotes.Flag:FireAllClients(plr, "Float B ("..hrp.Velocity.Y..")")
								task.spawn(function()
									hrp:SetNetworkOwner(nil)
									task.wait(0.7)
									hrp:SetNetworkOwner(plr)
								end)
								return
							end
						end
					end
				end

				lastCF = hrp.CFrame
			end
		end)
	end))
end))
