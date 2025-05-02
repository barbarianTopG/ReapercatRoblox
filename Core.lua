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
			plr:SetAttribute("NoclipException", tick() + 1)
			task.wait()
			plr.Character:PivotTo(pos)
		end,
		SetException = function(plr: Player, time: number)
			plr:SetAttribute("Exception", tick() + time)
		end,
		SetMultiplier = function(plr: Player, time: number, multi) : ()
			plr:SetAttribute('Multiplier', `{tick() + time}, {multi}`)
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
			CFrame = 18,
			Interval = 0.975,
			MaxViolations = 100
		},
		Float = {
			Checks = {
				A = true, -- Velocity
				B = true,
				C = true
			},
			Velocity = 60,
			Safety = 1.4,
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
			MaxCFrame = 40,
			MaxViolations = 30
		},
		Noclip = {
			Checks = {
				A = true -- Raycast
			},
			Flag = false
		}
	}
}

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.MaxParts = 1
overlapParams.CollisionGroup = 'Default'

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

local function raycastAround(pos, params)
	local result
	
	local res = 0
	
	for i = 1, 2 do
		local ray = workspace:Raycast(pos, Vector3.new((i == 1 and 7 or 0), 0, (i == 2 and 7 or 0)), params)
		if ray then
			result = ray
			res += 1
		end
	end
	for i = 1, 2 do
		local ray = workspace:Raycast(pos, Vector3.new((i == 1 and -7 or 0), 0, (i == 2 and -7 or 0)), params)
		if ray then
			result = ray
			res += 1
		end
	end
	return res >= 2 and result
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

local function getPlayerVeloMulti(plr: Player)
	if plr.Character and plr.Character:FindFirstChildOfClass('Humanoid') and plr.Character.Humanoid.SeatPart then
		if plr.Character.Humanoid.SeatPart:IsA('VehicleSeat') then
			return {
				Multiplier = 15,
				ExtaFloatTime = math.huge
			}
		end
	end
	local data = plr:GetAttribute('Multiplier')
	return data and tonumber(data:split(', ')[1]) > tick() and {
		Multiplier = tonumber(data:split(', ')[2]),
		ExtaFloatTime = 1
	} or {Multiplier = 1, ExtaFloatTime = 0}
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
	local rays = {workspace:Raycast(hrp.Position, plr.Character.PrimaryPart.CFrame.LookVector, params)}
	for i = 0, 5 do
		table.insert(rays, workspace:Raycast(hrp.Position, Vector3.new(
			i == 1 and 2 or i == 3 and -2 or 0,
			-5,
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

local laddercache = {}
local function isOnLadder(plr: Player)
	if laddercache[plr] and laddercache[plr] > tick() then return true end
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	local hrp: Part = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local rays = {workspace:Raycast(hrp.Position, plr.Character.PrimaryPart.CFrame.LookVector, params)}
	for i = 0, 7 do
		table.insert(rays, workspace:Raycast(hrp.Position, Vector3.new(
			i == 1 and 5 or i == 3 and -5 or 0,
			i == 5 and 5 or i == 6 and -5 or 0,
			i == 2 and 5 or i == 4 and -5 or 0
			), params))
	end

	local isOnTruss
	for i, v: RaycastResult in rays do
		if v.Instance and v.Instance.ClassName == "TrussPart" then
			warn('works!')
			isOnTruss = true
			laddercache[plr] = tick() + 0.5
			break
		end
	end

	return isOnTruss
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
	for i, v in {"Speed", "Float", "UnAct", "Noclip"} do
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
		local lastMovedir = hum.MoveDirection
		local lastGroundCF = hrp.CFrame
		local remainingAirTime = 0
		local checksLoop
		local insideapart
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
								remotes.Flag:FireAllClients(plr, "Unexpected Actions A ("..lastCF.Y - lastGroundCF.Y..")")
								hrp.CFrame = lastCF
								task.spawn(function()
									if hrp:CanSetNetworkOwnership() then
										hrp:SetNetworkOwner(nil)
									end
									hrp.CFrame = lastCF
									hrp.AssemblyLinearVelocity = Vector3.zero
									task.wait(1)
									hrp:SetNetworkOwner(plr)
								end)
							end
							
						elseif i == "B" then
							if hrp.AssemblyLinearVelocity.Y > (config.UnexpectedActions.MaxVelocity * getPlayerVeloMulti(plr).Multiplier) then
								vl.UnexpectedActions += 1 + math.random() * ((hrp.AssemblyLinearVelocity.Y) / 3) + 1
								remotes.Flag:FireAllClients(plr, "Unexpected Actions B ("..hrp.AssemblyLinearVelocity.Y..")")
								hrp.CFrame = lastCF
								task.spawn(function()
									if hrp:CanSetNetworkOwnership() then
										hrp:SetNetworkOwner(nil)
									end
									hrp.CFrame = lastCF
									hrp.AssemblyLinearVelocity = Vector3.zero
									task.wait(1)
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
										if hrp:CanSetNetworkOwnership() then
											hrp:SetNetworkOwner(nil)
										end
										hrp.CFrame = lastCF
										hrp.AssemblyLinearVelocity = Vector3.zero
										task.wait(1)
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
							local walking = isOnLadder(plr) and true or (hum.MoveDirection.Magnitude > 0.9 or lastMovedir.Magnitude > 0.9)
							
							local velo = math.max(hrp.AssemblyLinearVelocity.X, hrp.AssemblyLinearVelocity.Z) * (walking and (ping > 150 and 0.9 or 0.95) or (ping > 150 and 0.65 or 0.75))
							if (velo + (isOnLadder(plr) and -20 or 0)) > (config.Speed.WalkSpeed * getPlayerVeloMulti(plr).Multiplier) + 1.7 then
								vl.Speed += 1 + math.random() * ((velo - config.Speed.WalkSpeed + pingBonus) / 3) + 1
								remotes.Flag:FireAllClients(plr, "Speed B ("..velo..")")
								hrp.CFrame = lastCF
								task.spawn(function()
									if hrp:CanSetNetworkOwnership() then
										hrp:SetNetworkOwner(nil)
									end
									hrp.CFrame = lastCF
									hrp.AssemblyLinearVelocity = Vector3.zero
									task.wait(1)
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
								sps = math.floor((newpos - (oldpos * Vector3.new(1, 0, 1))).magnitude)
								if sps > (config.Speed.CFrame * getPlayerVeloMulti(plr).Multiplier) + pingBonus then
									vl.Speed += 1 + math.random() * ((sps - config.Speed.WalkSpeed + pingBonus) / 3) + 1
									remotes.Flag:FireAllClients(plr, "Speed C ("..sps..")")
									hrp.CFrame = lastCF
									task.spawn(function()
										if hrp:CanSetNetworkOwnership() then
											hrp:SetNetworkOwner(nil)
										end
										hrp.CFrame = lastCF
										hrp.AssemblyLinearVelocity = Vector3.zero
										task.wait(1)
										hrp:SetNetworkOwner(plr)
									end)
								end
							end)
						end
					end
				end

				if (isOnGround(plr) or isInWater(plr) or isOnLadder(plr)) and hrp:GetNetworkOwner() == plr or ping > 1000 then
					remainingAirTime = tick() + config.Float.Safety
					lastGroundCF = hrp.CFrame
				end
							
				-- FLOAT CHECKS
				for i, check in config.Float.Checks do
					if check and not isOnGround(plr) and not isInWater(plr) and not isOnLadder(plr) and getPlayerCheckException("Float", plr) <= 0 then
						if i == "A" then
							if remainingAirTime - tick() < config.Float.Safety / 2.222 and (hrp.AssemblyLinearVelocity.Y >= -15 and hrp.Position.Y >= lastGroundCF.Y) then
								vl.Float += 1 + math.random() * (hrp.AssemblyLinearVelocity.Y / 3) + 1
								remotes.Flag:FireAllClients(plr, "Float A ("..hrp.AssemblyLinearVelocity.Y..")")
								hrp.CFrame = lastCF
								task.spawn(function()
									hrp:SetNetworkOwner(nil)
									hrp.CFrame = lastCF
									hrp.AssemblyLinearVelocity = Vector3.zero
									task.wait(1)
									hrp:SetNetworkOwner(plr)
								end)
								return
							end
						elseif i == "B" then
							if hrp and hrp.Parent and (remainingAirTime - tick()) < config.Float.Safety / 4 and hrp.AssemblyLinearVelocity.Y >= -config.Float.Velocity then
								vl.Float += 1 + math.random() * (hrp.AssemblyLinearVelocity.Y / 3) + 1
								remotes.Flag:FireAllClients(plr, "Float B ("..hrp.AssemblyLinearVelocity.Y..")")
								hrp.CFrame = lastCF
								task.spawn(function()
									hrp:SetNetworkOwner(nil)
									hrp.CFrame = lastCF
									hrp.AssemblyLinearVelocity = Vector3.zero
									task.wait(1)
									hrp:SetNetworkOwner(plr)
								end)
							end
						elseif i == "C" then
							if hrp.AssemblyLinearVelocity.Y < 1 and (hrp.Position.Y - lastCF.Y) >= 5 and (remainingAirTime - tick()) < config.Float.Safety / 1.5 then
								vl.Float += 1 + math.random() * (hrp.Position.Y - lastCF.Y) + 1
								remotes.Flag:FireAllClients(plr, "Float C (Gain:"..(hrp.Position.Y - lastCF.Y)..", Air:"..(tick() - (remainingAirTime - config.Float.Safety))..")")
								hrp.CFrame = lastCF
								task.spawn(function()
									hrp:SetNetworkOwner(nil)
									hrp.CFrame = lastCF
									hrp.AssemblyLinearVelocity = Vector3.zero
									task.wait(1)
									hrp:SetNetworkOwner(plr)
								end)
							end	
						end
					end
				end

				-- NOCLIP CHECKS
				for i, check in config.Noclip.Checks do
					if check and getPlayerCheckException("Noclip", plr) <= 0 then
						if i == 'A' then
							overlapParams.FilterDescendantsInstances = {workspace.Vehicles, hrp.Parent}

							local radius = 0.1 
							local parts = workspace:GetPartBoundsInRadius(hrp.Position, radius, overlapParams)

							local isCurrentlyClipping = false
							local clippingPart = nil
							if #parts > 0 then
								for _, part in parts do
									if part and part:IsA("BasePart") and part.CanCollide then 
										isCurrentlyClipping = true
										clippingPart = part
										break
									end
								end
							end

							if isCurrentlyClipping then
								if not insideapart then
									vl.Float += 1
									remotes.Flag:FireAllClients(plr, "Noclip A ("..(clippingPart and clippingPart.Name or "UnknownPart")..")")
									hrp.CFrame = lastCF 
									task.spawn(function()
										hrp:SetNetworkOwner(nil)
										hrp.CFrame = lastCF
										hrp.AssemblyLinearVelocity = Vector3.zero
										task.wait(1)
										hrp:SetNetworkOwner(plr) 
									end)
									insideapart = true
									return
								else
									insideapart = true 
								end

							else
								if insideapart then
									insideapart = false
								end
							end
						end
					end
				end
				
				lastMovedir = hum.MoveDirection
				lastCF = hrp.CFrame
			end	
		end)
	end))
end))
