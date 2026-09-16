-- Movement, Automation, Traps & Guard Bypasses for Steal An Egg.
-- Anti-cheat compliant: ZERO teleportation. PathfindingService wall-avoidance navigation.
-- Automatic re-grab recovery if trapped by animals. Minimum money per second filtering.

local ctx = ...
local Util = ctx.require("core/Util")
local EggData = ctx.require("features/StealAnEgg/EggData")

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local ARRIVE_DISTANCE = 5        -- must be this close to fire the carry remote (server range ~300 studs is fine, but 5 ensures proximity prompt triggers)
local WAYPOINT_DISTANCE = 4.5
local SAFE_ZONE_NAMES = { "SafeZone", "SafeArea", "Base", "Baseplate", "SpawnArea", "PlayerPlot", "Plot" }
local RESPAWN_SAFE_POS   = Vector3.new(0, 5, 0)   -- teleport here after respawn when auto-farm is active

local Movement = {}
Movement.__index = Movement

local eggStateModule = nil
pcall(function()
	local eggStateMod = ReplicatedStorage:FindFirstChild("Client") and ReplicatedStorage.Client:FindFirstChild("EggState")
	if eggStateMod and eggStateMod:IsA("ModuleScript") then
		eggStateModule = require(eggStateMod)
	end
end)

local plotStateModule = nil
pcall(function()
	local psMod = ReplicatedStorage:FindFirstChild("Client") and ReplicatedStorage.Client:FindFirstChild("PlotState")
	if psMod and psMod:IsA("ModuleScript") then
		plotStateModule = require(psMod)
	end
end)

-- Universal executor HTTP POST helper for Discord Webhooks
local function sendWebhook(url, payload)
	if not url or url == "" or not string.find(url, "discord.com/api/webhooks") then
		return false, "Invalid Discord Webhook URL"
	end

	local body = HttpService:JSONEncode(payload)
	local headers = { ["Content-Type"] = "application/json" }

	local requestFn = (syn and syn.request) or request or http_request or (http and http.request)
	if requestFn then
		local ok, resp = pcall(requestFn, {
			Url = url,
			Method = "POST",
			Headers = headers,
			Body = body,
		})
		if ok and resp and (resp.StatusCode == 200 or resp.StatusCode == 204) then
			return true, "Webhook sent successfully"
		end
		return false, ok and tostring(resp and resp.StatusCode) or tostring(resp)
	end

	return false, "Executor does not support HTTP requests"
end

function Movement.new(config)
	local self = setmetatable({
		notify = config.notify or function() end,
		autoFarmAllRunning = false,
		autoFarmBestRunning = false,
		autoCashRunning = false,
		antiTrapRunning = false,
		monsterBypassRunning = false,
		antiRagdollRunning = false,
		antiKnockbackRunning = false,
		antiGuardHitRunning = false,
		autoTreadmillRunning = false,
		speedBypassRunning = false,
		webhookEnabled = false,
		webhookUrl = "",
		customSpeed = 28,
		minMoneyPerSec = 0,
		rememberedBasePos = nil,
		movementMode = "Tween",
		tweenSpeed = 110,
		movementElevation = 0,
		movementNoclip = true,
		returnToBase = true,
		_currentTween = nil,
		busy = false,
		connections = {},
	}, Movement)

	self:neutralizeAntiCheat()

	-- Remember initial spawn position as safe base fallback
	pcall(function()
		local root = Util.getRootPart()
		if root then
			self.rememberedBasePos = root.Position
		end
	end)

	return self
end

function Movement:_context()
	local hum = Util.getHumanoid()
	local root = Util.getRootPart()
	if not hum or not root then
		self.notify("Character not ready", "error")
		return nil, nil
	end
	return hum, root
end

-- Waits until the character is fully loaded and HumanoidRootPart is settled (not at spawn Y)
function Movement:_waitForCharacter(timeout)
	local deadline = os.clock() + (timeout or 10)
	while os.clock() < deadline do
		local hum = Util.getHumanoid()
		local root = Util.getRootPart()
		if hum and root and hum.Health > 0 then
			return true
		end
		task.wait(0.3)
	end
	return false
end

-- Called at the start of each farm cycle. If the character just respawned (velocity ~0 and
-- HumanoidRootPart is very close to a SpawnLocation), teleport them to the safe map center
-- so they don't immediately walk into the nearest wall.
function Movement:_handleRespawn()
	local root = Util.getRootPart()
	if not root then return end

	-- Detect spawn-wall proximity: if the character is within 10 studs of any SpawnLocation
	-- or their velocity is near-zero, they likely just respawned.
	local justSpawned = false
	for _, sp in ipairs(workspace:GetDescendants()) do
		if sp:IsA("SpawnLocation") then
			local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(sp.Position.X, 0, sp.Position.Z)).Magnitude
			if dist < 12 then
				justSpawned = true
				break
			end
		end
	end

	if justSpawned then
		-- Teleport to safe map centre so the walk path doesn't immediately hit the spawn wall
		pcall(function()
			root.CFrame = CFrame.new(RESPAWN_SAFE_POS)
		end)
		task.wait(0.5)
		self.notify("Respawned — moved to map centre, resuming farm...", "info")
	end
end

function Movement:neutralizeAntiCheat()
	-- Safe client-side attribute neutralization without destroying game scripts or blocking server sync
	pcall(function()
		workspace:SetAttribute("ClientObbyAntiTp", false)
	end)
end

function Movement:setMinMoney(amountStr)
	local text = string.lower(string.gsub(tostring(amountStr or ""), "[%$,%s]", ""))
	if text == "" or text == "0" then
		self.minMoneyPerSec = 0
		self.notify("Min money filter cleared (farming all eggs)", "info")
		return
	end
	local num, suffix = string.match(text, "^([%d%.]+)([kmbt]?)$")
	if num then
		local val = tonumber(num) or 0
		if suffix == "k" then val = val * 1e3
		elseif suffix == "m" then val = val * 1e6
		elseif suffix == "b" then val = val * 1e9
		elseif suffix == "t" then val = val * 1e12 end
		self.minMoneyPerSec = val
		self.notify(string.format("Min money filter: %s (ignoring below)", EggData.formatMoney(val)), "success")
	else
		self.notify("Invalid money format (use e.g. 1M, 500k, 10000)", "warning")
	end
end

function Movement:setSpeed(speed)
	self.customSpeed = math.clamp(tonumber(speed) or 60, 1, 1000)
	local hum = Util.getHumanoid()
	if hum then
		hum.WalkSpeed = self.customSpeed
	end
end

function Movement:setMovementMode(mode)
	local validModes = {
		["Tween"] = true,
		["Walk (Pathfinding)"] = true,
		["Ragdoll Exploit"] = true,
		["CFrame Glide"] = true,
		["Instant Teleport"] = true,
	}
	if validModes[mode] then
		self.movementMode = mode
		self.notify(string.format("Auto Steal movement: %s", mode), "success")
	else
		self.movementMode = "Tween"
	end
end

function Movement:setTweenSpeed(speed)
	self.tweenSpeed = math.clamp(tonumber(speed) or 110, 10, 500)
end

function Movement:setElevation(offset)
	self.movementElevation = math.clamp(tonumber(offset) or 0, 0, 100)
end

function Movement:toggleMovementNoclip(enabled)
	self.movementNoclip = enabled == true
end

function Movement:toggleReturnToBase(enabled)
	self.returnToBase = enabled == true
end

function Movement:toggleSpeedBypass(enabled)
	self.speedBypassRunning = enabled == true
	if self.speedBypassRunning then
		self:neutralizeAntiCheat()
		local hum, root = self:_context()
		local safeWalk = math.min(self.customSpeed, 38)
		if hum then
			hum.WalkSpeed = safeWalk
		end
		self.notify(string.format("Speed Bypass active (Speed: %d)", self.customSpeed), "success")

		if not self.connections.speedLoop then
			self.connections.speedLoop = RunService.Heartbeat:Connect(function(dt)
				if not self.speedBypassRunning and not self.autoFarmAllRunning and not self.autoFarmBestRunning then
					return
				end
				local currentHum = Util.getHumanoid()
				local currentRoot = Util.getRootPart()
				if not currentHum or not currentRoot then
					return
				end

				-- Maintain safe humanoid walkspeed (up to 38 studs/s never rubberbands)
				local targetSafe = math.min(self.customSpeed, 38)
				if currentHum.WalkSpeed ~= targetSafe then
					currentHum.WalkSpeed = targetSafe
				end

				if not self.autoFarmAllRunning and not self.autoFarmBestRunning then
					local moveDir = currentHum.MoveDirection
					if moveDir.Magnitude > 0 and self.customSpeed > 38 then
						-- Smooth CFrame micro-stepping for higher speeds without triggering physics velocity flags
						local extraSpeed = self.customSpeed - 38
						local step = moveDir * (extraSpeed * dt)
						currentRoot.CFrame = currentRoot.CFrame + step
					end
				end
			end)
		end
	else
		if self.connections.speedLoop then
			self.connections.speedLoop:Disconnect()
			self.connections.speedLoop = nil
		end
		local hum = Util.getHumanoid()
		if hum then
			hum.WalkSpeed = 16
		end
		self.notify("Speed Bypass disabled (Speed: 16)", "info")
	end
end

function Movement:setWebhook(url)
	self.webhookUrl = tostring(url or "")
end

function Movement:toggleWebhook(enabled)
	self.webhookEnabled = enabled == true
	if self.webhookEnabled then
		self.notify("Egg steal webhook logging enabled", "success")
	else
		self.notify("Egg steal webhook logging disabled", "info")
	end
end

function Movement:testWebhook()
	if not self.webhookUrl or self.webhookUrl == "" then
		self.notify("Please paste a Discord Webhook URL first", "error")
		return false
	end

	local payload = {
		embeds = {
			{
				title = "❄️ Frost Hub • Webhook Connected",
				description = "Test message received successfully! Stolen eggs will be logged here.",
				color = 58879,
				fields = {
					{ name = "Player", value = LocalPlayer.Name, inline = true },
					{ name = "Game", value = "Steal An Egg", inline = true },
				},
				footer = { text = "Frost Hub • Steal An Egg Edition" },
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			},
		},
	}

	self.notify("Sending test webhook...", "info")
	local ok, msg = sendWebhook(self.webhookUrl, payload)
	if ok then
		self.notify("Test webhook delivered!", "success")
		return true
	else
		self.notify("Webhook failed: " .. tostring(msg), "error")
		return false
	end
end

function Movement:logEggStolen(entry)
	if not entry then return end

	local cleanDisplay = entry.cleanDisplay or string.format("(%s) %s", entry.eggName or "Normal Egg", entry.petName or "Chicken")
	local moneyText = entry.moneyText or "+$50/s"
	local rarity = entry.rarity or "Common"

	-- 1. Always log to Roblox F9 console
	print(string.format("[Frost] 🥚 Egg Stolen & Deposited: %s | Rarity: %s | Income: %s", cleanDisplay, rarity, moneyText))

	-- 2. Notify HUD
	self.notify(string.format("Deposited: %s (%s)", cleanDisplay, moneyText), "success")

	-- 3. Discord Webhook if configured
	if not self.webhookEnabled or not self.webhookUrl or self.webhookUrl == "" then
		return
	end

	local rarityColorInt = 16777215
	if rarity == "Divine" then
		rarityColorInt = 64764
	elseif rarity == "Mythic" then
		rarityColorInt = 16725860
	elseif rarity == "Legendary" then
		rarityColorInt = 16758046
	elseif rarity == "Epic" then
		rarityColorInt = 12144895
	elseif rarity == "Rare" then
		rarityColorInt = 3988479
	elseif rarity == "Uncommon" then
		rarityColorInt = 5631864
	end

	local payload = {
		embeds = {
			{
				title = "🥚 Egg Stolen & Deposited!",
				description = string.format("**%s** stole a **%s** (%s)!", LocalPlayer.Name, cleanDisplay, rarity),
				color = rarityColorInt,
				fields = {
					{ name = "Egg & Pet", value = cleanDisplay, inline = true },
					{ name = "Money / Sec", value = moneyText, inline = true },
					{ name = "Rarity", value = rarity, inline = true },
					{ name = "Player", value = LocalPlayer.Name, inline = true },
				},
				footer = { text = "Frost Hub • Steal An Egg" },
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			},
		},
	}

	Util.spawn(function()
		sendWebhook(self.webhookUrl, payload)
	end)
end

-- 100% Reliable Player Plot & Deposit Location Finder (regardless of which plot is assigned)
function Movement:findBasePosition()
	-- 1. Check official PlotState module
	if plotStateModule and plotStateModule.GetLocalPlot then
		local ok, plot = pcall(plotStateModule.GetLocalPlot)
		if ok and plot and typeof(plot) == "Instance" then
			local deposit = plot:FindFirstChild("EggPen", true)
				or plot:FindFirstChild("Deposit", true)
				or plot:FindFirstChild("Base", true)
				or plot:FindFirstChild("Pad", true)
			if deposit then
				local pos = EggData.worldPositionOf(deposit)
				if pos then return pos + Vector3.new(0, 3, 0) end
			end
			local pos = EggData.worldPositionOf(plot)
			if pos then return pos + Vector3.new(0, 3, 0) end
		end
	end

	-- 2. Search workspace Plots for player's assigned plot
	local plotsFolder = workspace:FindFirstChild("Plots")
		or workspace:FindFirstChild("PlayerPlots")
		or workspace:FindFirstChild("Plots", true)

	if plotsFolder then
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			local owner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerName") or plot:GetAttribute("OwnerId")
			local isMatch = (owner == LocalPlayer.Name or owner == tostring(LocalPlayer.UserId) or owner == LocalPlayer.UserId)

			if not isMatch then
				-- Check sign or child text label
				local sign = plot:FindFirstChild("Sign", true) or plot:FindFirstChild("OwnerSign", true)
				if sign then
					for _, d in ipairs(sign:GetDescendants()) do
						if d:IsA("TextLabel") and (string.find(d.Text, LocalPlayer.Name, 1, true) or string.find(d.Text, LocalPlayer.DisplayName, 1, true)) then
							isMatch = true
							break
						end
					end
				end
			end

			if isMatch then
				local deposit = plot:FindFirstChild("EggPen", true)
					or plot:FindFirstChild("Deposit", true)
					or plot:FindFirstChild("Base", true)
					or plot:FindFirstChild("Collector", true)
				if deposit then
					local pos = EggData.worldPositionOf(deposit)
					if pos then
						self.rememberedBasePos = pos + Vector3.new(0, 3, 0)
						return self.rememberedBasePos
					end
				end
				local pos = EggData.worldPositionOf(plot)
				if pos then
					self.rememberedBasePos = pos + Vector3.new(0, 3, 0)
					return self.rememberedBasePos
				end
			end
		end
	end

	-- 3. Return remembered base position or spawn
	if self.rememberedBasePos then
		return self.rememberedBasePos
	end

	for _, name in ipairs(SAFE_ZONE_NAMES) do
		local found = workspace:FindFirstChild(name, true)
		if found then
			local position = EggData.worldPositionOf(found)
			if position then
				return position + Vector3.new(0, 3, 0)
			end
		end
	end

	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position + Vector3.new(0, 3, 0)
	end

	return Vector3.new(0, 10, 0)
end

function Movement:isTrapped()
	local char = LocalPlayer.Character
	if not char then return false end
	if char:GetAttribute("IsTrapped") == true then
		return true
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and (hum.PlatformStand or hum.Sit or hum.Health <= 0) then
		return true
	end
	return false
end

-- PathfindingService wall avoidance: computes safe waypoints around walls and geometry
function Movement:computePathWaypoints(startPos, targetPos)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 6,
	})
	local ok = pcall(function()
		path:ComputeAsync(startPos, targetPos)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

-- Safe pathing to target position: follows PathfindingService waypoints, avoids walls, auto-unstucks
function Movement:safeWalkTo(targetPos, timeoutSeconds)
	local hum, root = self:_context()
	if not hum or not root then
		return false
	end

	local speed = self.customSpeed
	hum.WalkSpeed = speed

	local deadline = os.clock() + (timeoutSeconds or 15)
	local waypoints = self:computePathWaypoints(root.Position, targetPos)
	local waypointIdx = 1

	local lastPos = root.Position
	local stuckCount = 0

	while os.clock() < deadline and (self.autoFarmAllRunning or self.autoFarmBestRunning) do
		if self:isTrapped() then
			self.notify("Trapped by animal! Waiting for trap to release...", "warning")
			while self:isTrapped() and (self.autoFarmAllRunning or self.autoFarmBestRunning) do
				task.wait(0.5)
			end
			self.notify("Trap cleared! Resuming...", "info")
			return false, "trapped"
		end

		local curHum = Util.getHumanoid()
		local curRoot = Util.getRootPart()
		if not curHum or not curRoot then
			break
		end

		if curHum.WalkSpeed ~= speed then
			curHum.WalkSpeed = speed
		end

		-- Target point is either the next pathfinding waypoint or final destination
		local currentGoal = targetPos
		if waypoints and waypointIdx <= #waypoints then
			currentGoal = waypoints[waypointIdx].Position
			local wpDist = (Vector3.new(currentGoal.X, 0, currentGoal.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z)).Magnitude
			if wpDist <= WAYPOINT_DISTANCE then
				waypointIdx = waypointIdx + 1
				if waypointIdx <= #waypoints then
					currentGoal = waypoints[waypointIdx].Position
					if waypoints[waypointIdx].Action == Enum.PathWaypointAction.Jump then
						curHum.Jump = true
					end
				else
					currentGoal = targetPos
				end
			end
		end

		local delta = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z))
		if delta.Magnitude <= ARRIVE_DISTANCE then
			return true
		end

		-- Steer humanoid directly toward current waypoint / target
		curHum:MoveTo(currentGoal)

		-- Smooth pathing without physics velocity spikes that cause rubberband
		local safeSpeed = math.min(speed, 38)
		if curHum.WalkSpeed ~= safeSpeed then
			curHum.WalkSpeed = safeSpeed
		end

		local goalDelta = (Vector3.new(currentGoal.X, 0, currentGoal.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z))
		if speed > 38 and goalDelta.Magnitude > 2 then
			local extraSpeed = speed - 38
			local step = goalDelta.Unit * math.min(extraSpeed * 0.15, 3.5)
			curRoot.CFrame = curRoot.CFrame + step
		end

		-- Wall-hit & Stuck Detection
		local movedDist = (Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z) - Vector3.new(lastPos.X, 0, lastPos.Z)).Magnitude
		if movedDist < 0.6 then
			stuckCount = stuckCount + 1
			if stuckCount >= 3 then
				-- Jump to clear fence/obstacle edge
				curHum.Jump = true
				-- Recompute path around the obstacle
				waypoints = self:computePathWaypoints(curRoot.Position, targetPos)
				waypointIdx = 1
				stuckCount = 0
			end
		else
			stuckCount = 0
		end
		lastPos = curRoot.Position

		task.wait(0.15)
	end

	local finalRoot = Util.getRootPart()
	if finalRoot then
		local finalDelta = (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(finalRoot.Position.X, 0, finalRoot.Position.Z))
		return finalDelta.Magnitude <= ARRIVE_DISTANCE
	end
	return false
end

-- Searches for any egg-related ProximityPrompt near a position
function Movement:findNearbyPrompt(pos, maxDist)
	maxDist = maxDist or 25
	local bestPrompt = nil
	local bestDist = maxDist

	-- 1. Check workspace AreaEggSlotsClient if present
	local clientFolder = workspace:FindFirstChild("AreaEggSlotsClient")
	if clientFolder then
		for _, child in ipairs(clientFolder:GetChildren()) do
			local p = child:FindFirstChildWhichIsA("ProximityPrompt", true)
			if p and p.Parent and p.Parent:IsA("BasePart") then
				local d = (p.Parent.Position - pos).Magnitude
				if d < bestDist then
					bestDist = d
					bestPrompt = p
				end
			end
		end
	end

	-- 2. Scan workspace descendants for ProximityPrompts near pos
	pcall(function()
		for _, desc in ipairs(workspace:GetDescendants()) do
			local ok, isPP = pcall(function() return typeof(desc) == "Instance" and desc:IsA("ProximityPrompt") end)
			if ok and isPP then
				local promptPart = desc.Parent
				if promptPart and typeof(promptPart) == "Instance" and promptPart:IsA("BasePart") then
					local dist = (promptPart.Position - pos).Magnitude
					if dist < bestDist then
						local action = tostring(desc.ActionText or "")
						local name = tostring(desc.Name or "")
						local isEggAction = string.find(string.lower(action), "steal", 1, true)
							or string.find(string.lower(action), "take", 1, true)
							or string.find(string.lower(action), "grab", 1, true)
							or string.find(string.lower(name), "egg", 1, true)
							or string.find(string.lower(name), "carry", 1, true)
						if isEggAction then
							bestDist = dist
							bestPrompt = desc
						elseif not bestPrompt then
							bestPrompt = desc
							bestDist = dist
						end
					end
				end
			end
		end
	end)

	return bestPrompt
end

-- Triggers a ProximityPrompt bypassing client-side limitations
function Movement:triggerPrompt(prompt)
	if not prompt or typeof(prompt) ~= "Instance" or not prompt:IsA("ProximityPrompt") then
		return false
	end

	pcall(function()
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 60
	end)

	if fireproximityprompt then
		pcall(function() fireproximityprompt(prompt, 0, true) end)
		pcall(function() fireproximityprompt(prompt, 0) end)
		pcall(function() fireproximityprompt(prompt) end)
	end

	-- Client-side instant hold bypass: setting HoldDuration = 0 triggers prompt instantly on InputHoldBegin
	pcall(function()
		local origHold = prompt.HoldDuration
		prompt.HoldDuration = 0
		prompt:InputHoldBegin()
		task.wait(0.06)
		prompt:InputHoldEnd()
		task.delay(0.5, function()
			pcall(function() prompt.HoldDuration = origHold end)
		end)
	end)

	return true
end

-- Steals an egg by invoking remotes and triggering the ProximityPrompt
function Movement:stealEgg(targetEntry)
	local _, root = self:_context()
	if not root or not targetEntry then
		return false
	end

	local eggUid = targetEntry.uid
	local eggModel = (typeof(targetEntry.model) == "Instance" and targetEntry.model)
		or (typeof(targetEntry.instance) == "Instance" and targetEntry.instance)
		or nil
	local slotKey = targetEntry.slotKey

	-- 1. Networking remotes invocation
	pcall(function()
		local networking = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
		if networking then
			local rfCarry = networking:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
			if rfCarry and rfCarry:IsA("RemoteFunction") then
				pcall(function() rfCarry:InvokeServer(eggUid) end)
				if slotKey then
					pcall(function() rfCarry:InvokeServer(eggUid, slotKey) end)
				end
				pcall(function() rfCarry:InvokeServer({ Uid = eggUid, SlotKey = slotKey }) end)
				if eggModel and typeof(eggModel) == "Instance" then
					pcall(function() rfCarry:InvokeServer(eggModel) end)
				end
			end

			-- Also search any other remotes with carry/steal in their name
			for _, child in ipairs(networking:GetChildren()) do
				local cName = string.lower(child.Name)
				if string.find(cName, "carry", 1, true) or string.find(cName, "steal", 1, true) or string.find(cName, "fieldegg", 1, true) then
					if child:IsA("RemoteFunction") then
						pcall(function() child:InvokeServer(eggUid) end)
						if slotKey then pcall(function() child:InvokeServer(eggUid, slotKey) end) end
					elseif child:IsA("RemoteEvent") then
						pcall(function() child:FireServer(eggUid) end)
						if slotKey then pcall(function() child:FireServer(eggUid, slotKey) end) end
					end
				end
			end
		end
	end)

	-- 2. ProximityPrompt trigger
	local prompt = targetEntry.prompt
	if not prompt or typeof(prompt) ~= "Instance" or not prompt.Parent then
		if eggModel and typeof(eggModel) == "Instance" then
			prompt = EggData.getPrompt(eggModel)
		end
	end
	if not prompt or typeof(prompt) ~= "Instance" or not prompt.Parent then
		if typeof(targetEntry.instance) == "Instance" then
			prompt = EggData.getPrompt(targetEntry.instance)
		end
	end
	if not prompt or typeof(prompt) ~= "Instance" or not prompt.Parent then
		-- Search near the character's arrival position
		prompt = self:findNearbyPrompt(root.Position, 25)
	end

	if prompt and typeof(prompt) == "Instance" and prompt:IsA("ProximityPrompt") then
		self:triggerPrompt(prompt)
	end

	-- 3. Game module direct call
	if eggStateModule and eggStateModule.CarryFieldEgg and eggUid then
		pcall(function()
			eggStateModule.CarryFieldEgg(eggUid, slotKey)
		end)
	end

	return true
end

function Movement:isCarryingEgg()
	local char = LocalPlayer.Character
	if not char then return false end

	-- 1. Check Tool in Character (equipped egg)
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") and string.find(string.lower(child.Name), "egg", 1, true) then
			return true
		end
	end

	-- 2. Check Tool in Backpack (egg in inventory)
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") and string.find(string.lower(item.Name), "egg", 1, true) then
				return true
			end
		end
	end

	-- 3. Strict boolean / string carry attributes on Character
	for _, attr in ipairs({ "Carrying", "CarryingEgg", "HasEgg", "IsCarrying", "HoldingEgg" }) do
		local val = char:GetAttribute(attr)
		if val == true or (type(val) == "string" and val ~= "") then
			return true
		end
		local pVal = LocalPlayer:GetAttribute(attr)
		if pVal == true or (type(pVal) == "string" and pVal ~= "") then
			return true
		end
	end

	-- 4. Check EggState game module
	if eggStateModule then
		if type(eggStateModule.IsCarryingEgg) == "function" then
			local ok, res = pcall(eggStateModule.IsCarryingEgg)
			if ok and res == true then return true end
		end
		if type(eggStateModule.GetCarriedEgg) == "function" then
			local ok, res = pcall(eggStateModule.GetCarriedEgg)
			if ok and type(res) == "table" and res.Uid ~= nil then return true end
		end
	end

	-- 5. Specifically named CarriedEgg model in Character
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Model") and (child.Name == "CarriedEgg" or string.find(string.lower(child.Name), "carriedegg", 1, true)) then
			return true
		end
	end

	return false
end

local function teleportCharacter(char, targetCF)
	if not char then return end
	pcall(function()
		char:PivotTo(targetCF)
	end)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
				part.CFrame = targetCF
			end)
		end
	end
end

local function forceRagdoll(hum, char)
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		hum.PlatformStand = true
		hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
	end)
end

local function unragdoll(hum, char)
	pcall(function()
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end)
end

-- Exploit Auto-Steal Sequence (Guaranteed Ragdoll & Boss Evasion):
-- 1. Steal nearest decoy egg
-- 2. Guard hit or self-induced ragdoll (guarantees ragdoll state every time)
-- 3. Teleport all character parts to designated egg during ragdoll
-- 4. Steal designated egg & recover
-- 5. Teleport 50 studs above ground (Y + 50) completely out of boss/guard range
-- 6. Fast runway sprint back to spawn safe zone
function Movement:exploitSteal(target)
	local hum, root = self:_context()
	if not hum or not root or hum.Health <= 0 then
		return false
	end

	local char = LocalPlayer.Character

	-- Step 1: Steal the nearest decoy egg
	local decoy = EggData.closest(nil, 0)
	if decoy and decoy.uid ~= target.uid then
		teleportCharacter(char, CFrame.new(decoy.position + Vector3.new(0, 2, 0)))
		task.wait(0.08)

		-- Trigger steal on decoy egg
		self:stealEgg(decoy)

		-- Step 2: Wait briefly for guard hit; if guard doesn't hit within 0.5s, force self-ragdoll
		local startHealth = hum.Health
		local guardWaitDeadline = os.clock() + 0.6
		local gotHit = false

		while os.clock() < guardWaitDeadline and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
			local state = hum:GetState()
			if state == Enum.HumanoidStateType.Ragdoll
				or state == Enum.HumanoidStateType.FallingDown
				or hum.PlatformStand
				or hum.Health < startHealth
			then
				gotHit = true
				break
			end
			task.wait(0.02)
		end

		-- Guarantee ragdoll state even if guard was far or missed
		forceRagdoll(hum, char)
		task.wait(0.05)

		-- Step 3: MOVE ALL CHARACTER PARTS TO DESIGNATED EGG WHILE RAGDOLLED!
		local targetCF = CFrame.new(target.position + Vector3.new(0, 2, 0))
		teleportCharacter(char, targetCF)
		task.wait(0.1)

		-- Step 4: Steal designated egg
		print(string.format("[Frost] ⚡ Stealing designated egg (%s - %s)!", target.cleanDisplay or target.eggName or "Egg", EggData.formatMoney(target.moneyPerSec)))
		self:stealEgg(target)
		task.wait(0.08)

		-- Recover from ragdoll
		unragdoll(hum, char)
		task.wait(0.06)
	else
		-- Self-ragdoll before teleporting to target egg
		forceRagdoll(hum, char)
		task.wait(0.04)
		local targetCF = CFrame.new(target.position + Vector3.new(0, 2, 0))
		teleportCharacter(char, targetCF)
		task.wait(0.08)
		self:stealEgg(target)
		unragdoll(hum, char)
		task.wait(0.06)
	end

	if not (self.autoFarmBestRunning or self.autoFarmAllRunning) then
		return false
	end

	-- Confirm carried egg
	local collected = false
	local targetCarryDeadline = os.clock() + 2.5
	while os.clock() < targetCarryDeadline and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
		if self:isCarryingEgg() then
			collected = true
			break
		end
		self:stealEgg(target)
		task.wait(0.2)
	end

	if not collected then
		self.notify(string.format("⚠️ Missed %s (taken or prompt failed). Skipping...", target.eggName or target.petName or "Egg"), "warning")
		return false
	end

	self.notify(string.format("🥚 Collected %s! Returning to base...", target.eggName or target.petName or "Egg"), "success")

	-- Step 5: Teleport 50 studs above ground (Y + 50) completely clear of boss attack cylinder
	local highY = root.Position.Y + 50
	teleportCharacter(char, CFrame.new(root.Position.X, highY, root.Position.Z))
	task.wait(0.04)

	-- Step 6: Fast sprint back to safe zone above boss reach
	local basePos = self:findBasePosition()
	if basePos then
		local startPos = root.Position
		local targetAirPos = Vector3.new(basePos.X, highY, basePos.Z)
		local delta = targetAirPos - startPos
		local dist = (Vector3.new(delta.X, 0, delta.Z)).Magnitude

		-- Spawn temporary solid runway platform ("the thing") 50 studs high
		local runway = nil
		pcall(function()
			runway = Instance.new("Part")
			runway.Name = "SafeRunwayThing"
			runway.Size = Vector3.new(14, 1, math.max(dist + 30, 40))
			runway.CFrame = CFrame.new(startPos:Lerp(targetAirPos, 0.5) - Vector3.new(0, 3.2, 0), targetAirPos - Vector3.new(0, 3.2, 0))
			runway.Anchored = true
			runway.CanCollide = true
			runway.Transparency = 1
			runway.Parent = workspace
		end)

		-- Fast return speed (55-65 studs/s) safely high above ground obstacles and bosses
		local fastAirSpeed = math.clamp(self.customSpeed or 58, 45, 75)
		hum.WalkSpeed = fastAirSpeed

		local walkStart = os.clock()
		local maxWalkTime = math.clamp(dist / fastAirSpeed + 1.5, 0.5, 8)

		while os.clock() - walkStart < maxWalkTime and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
			local currentDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(targetAirPos.X, 0, targetAirPos.Z)).Magnitude
			if currentDist <= 5 then
				break
			end

			hum:MoveTo(targetAirPos)

			-- Smooth micro-assist along runway
			local toBaseDir = (Vector3.new(targetAirPos.X - root.Position.X, 0, targetAirPos.Z - root.Position.Z))
			if toBaseDir.Magnitude > 0.1 then
				local step = toBaseDir.Unit * math.min(fastAirSpeed * 0.03, toBaseDir.Magnitude)
				root.CFrame = CFrame.new(root.Position.X + step.X, highY, root.Position.Z + step.Z)
			end
			task.wait(0.03)
		end

		if runway then
			pcall(function() runway:Destroy() end)
		end

		-- Drop down into the base safe zone to claim/deposit
		teleportCharacter(char, CFrame.new(basePos + Vector3.new(0, 3, 0)))
		task.wait(0.2)
	end

	self:logEggStolen(target)
	return true
end

function Movement:tweenTo(targetPos, speed)
	local hum, root = self:_context()
	if not hum or not root or hum.Health <= 0 then
		return false
	end

	local char = LocalPlayer.Character
	local moveSpeed = tonumber(speed) or self.tweenSpeed or 110
	local targetCF = typeof(targetPos) == "CFrame" and targetPos or CFrame.new(targetPos)

	local dist = (targetCF.Position - root.Position).Magnitude
	if dist < 2 then
		return true
	end

	-- Fast calculation: snappy, responsive transit without dragging
	local duration = math.clamp(dist / math.max(moveSpeed, 10), 0.04, 15)

	pcall(function()
		hum.PlatformStand = true
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)

	local noclipConn = nil
	if self.movementNoclip then
		noclipConn = RunService.Stepped:Connect(function()
			if char and char.Parent then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") and part.CanCollide then
						part.CanCollide = false
					end
				end
			end
		end)
	end

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(root, tweenInfo, { CFrame = targetCF })
	self._currentTween = tween

	local completed = false
	local conn = tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			completed = true
		end
	end)

	tween:Play()

	local deadline = os.clock() + duration + 0.3
	while not completed and os.clock() < deadline and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
		local curHum, curRoot = self:_context()
		if not curHum or not curRoot or curHum.Health <= 0 then
			break
		end
		curRoot.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.03)
	end

	pcall(function()
		conn:Disconnect()
	end)
	if not completed then
		pcall(function()
			tween:Cancel()
		end)
	end
	self._currentTween = nil

	if noclipConn then
		pcall(function()
			noclipConn:Disconnect()
		end)
	end

	pcall(function()
		root.CFrame = targetCF
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		hum.PlatformStand = false
	end)

	local finalRoot = Util.getRootPart()
	if finalRoot then
		local finalDist = (targetCF.Position - finalRoot.Position).Magnitude
		return finalDist <= 8
	end
	return false
end

function Movement:tweenSteal(target)
	local hum, root = self:_context()
	if not hum or not root or hum.Health <= 0 then
		return false
	end

	local eggPos = target.position
	if not eggPos then
		return false
	end

	-- 1. Elevation transit to glide over obstacles
	if self.movementElevation and self.movementElevation > 0 then
		local highPos = Vector3.new(eggPos.X, math.max(root.Position.Y, eggPos.Y) + self.movementElevation, eggPos.Z)
		self:tweenTo(highPos, self.tweenSpeed)
		if not (self.autoFarmBestRunning or self.autoFarmAllRunning) then return false end
	end

	-- 2. Tween right to the egg
	self:tweenTo(eggPos + Vector3.new(0, 1.5, 0), self.tweenSpeed)
	if not (self.autoFarmBestRunning or self.autoFarmAllRunning) then return false end

	-- 3. VERIFY PHYSICAL ARRIVAL: Player MUST be physically near the egg before attempting to collect!
	local curHum, curRoot = self:_context()
	if not curRoot then return false end
	local currentDist = (curRoot.Position - eggPos).Magnitude
	if currentDist > 14 then
		-- Snap to egg if slightly off
		self:tweenTo(eggPos + Vector3.new(0, 1.5, 0), self.tweenSpeed)
		curRoot = Util.getRootPart()
		if not curRoot or (curRoot.Position - eggPos).Magnitude > 14 then
			self.notify(string.format("⚠️ Transit incomplete (dist: %.0f studs). Skipping...", (curRoot and (curRoot.Position - eggPos).Magnitude or 999)), "warning")
			return false
		end
	end

	-- 4. Try stealing with prompt discovery and retries (staying at the egg)
	local collected = false
	local deadline = os.clock() + 3.0
	while os.clock() < deadline and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
		self:stealEgg(target)
		task.wait(0.2)
		if self:isCarryingEgg() then
			collected = true
			break
		end
	end

	-- 5. Only return to base if an egg was genuinely collected!
	if collected then
		self.notify(string.format("🥚 Collected %s! Returning to base...", target.eggName or target.petName or "Egg"), "success")
		if self.returnToBase then
			local basePos = self:findBasePosition()
			if basePos then
				if self.movementElevation and self.movementElevation > 0 then
					local highBase = Vector3.new(basePos.X, math.max(eggPos.Y, basePos.Y) + self.movementElevation, basePos.Z)
					self:tweenTo(highBase, self.tweenSpeed)
					if not (self.autoFarmBestRunning or self.autoFarmAllRunning) then return false end
				end

				self:tweenTo(basePos + Vector3.new(0, 0.5, 0), self.tweenSpeed)

				local depositPrompt = self:findNearbyPrompt(basePos, 15)
				if depositPrompt then
					self:triggerPrompt(depositPrompt)
				end

				local depDeadline = os.clock() + 1.8
				while os.clock() < depDeadline and self:isCarryingEgg() and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
					task.wait(0.1)
				end
			end
		end

		self:logEggStolen(target)
		return true
	else
		self.notify(string.format("⚠️ Missed %s (taken or prompt failed). Skipping...", target.eggName or target.petName or "Egg"), "warning")
		return false
	end
end

function Movement:walkSteal(target)
	local hum, root = self:_context()
	if not hum or not root or hum.Health <= 0 then
		return false
	end

	local eggPos = target.position
	if not eggPos then
		return false
	end

	local arrived = self:safeWalkTo(eggPos, 20)
	if not arrived or not (self.autoFarmBestRunning or self.autoFarmAllRunning) then
		return false
	end

	local curHum, curRoot = self:_context()
	if not curRoot or (curRoot.Position - eggPos).Magnitude > 14 then
		return false
	end

	local collected = false
	local deadline = os.clock() + 3.0
	while os.clock() < deadline and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
		self:stealEgg(target)
		task.wait(0.2)
		if self:isCarryingEgg() then
			collected = true
			break
		end
	end

	if collected then
		self.notify(string.format("🥚 Collected %s! Returning to base...", target.eggName or target.petName or "Egg"), "success")
		if self.returnToBase then
			local basePos = self:findBasePosition()
			if basePos then
				self:safeWalkTo(basePos, 25)

				local depositPrompt = self:findNearbyPrompt(basePos, 15)
				if depositPrompt then
					self:triggerPrompt(depositPrompt)
				end

				local depDeadline = os.clock() + 1.8
				while os.clock() < depDeadline and self:isCarryingEgg() and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
					task.wait(0.1)
				end
			end
		end

		self:logEggStolen(target)
		return true
	else
		self.notify(string.format("⚠️ Missed %s (taken or prompt failed). Skipping...", target.eggName or target.petName or "Egg"), "warning")
		return false
	end
end

function Movement:glideSteal(target)
	local hum, root = self:_context()
	if not hum or not root or hum.Health <= 0 then
		return false
	end

	local eggPos = target.position
	if not eggPos then
		return false
	end

	local function glideTo(dest, maxTime)
		local char = LocalPlayer.Character
		local deadline = os.clock() + (maxTime or 15)
		local noclipConn = nil
		if self.movementNoclip then
			noclipConn = RunService.Stepped:Connect(function()
				if char and char.Parent then
					for _, p in ipairs(char:GetDescendants()) do
						if p:IsA("BasePart") and p.CanCollide then
							p.CanCollide = false
						end
					end
				end
			end)
		end

		local speed = self.tweenSpeed or 110
		while os.clock() < deadline and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
			local curHum, curRoot = self:_context()
			if not curHum or not curRoot or curHum.Health <= 0 then break end
			local delta = (dest - curRoot.Position)
			if delta.Magnitude <= 4 then break end

			local dt = RunService.Heartbeat:Wait()
			local stepDist = math.min(speed * dt, delta.Magnitude)
			curRoot.CFrame = curRoot.CFrame + (delta.Unit * stepDist)
			curRoot.AssemblyLinearVelocity = Vector3.zero
		end

		if noclipConn then
			pcall(function() noclipConn:Disconnect() end)
		end
	end

	if self.movementElevation and self.movementElevation > 0 then
		glideTo(Vector3.new(eggPos.X, math.max(root.Position.Y, eggPos.Y) + self.movementElevation, eggPos.Z), 10)
	end
	glideTo(eggPos + Vector3.new(0, 1.5, 0), 10)
	if not (self.autoFarmBestRunning or self.autoFarmAllRunning) then return false end

	local curHumG, curRootG = self:_context()
	if not curRootG or (curRootG.Position - eggPos).Magnitude > 14 then
		return false
	end

	local collected = false
	local deadline = os.clock() + 3.0
	while os.clock() < deadline and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
		self:stealEgg(target)
		task.wait(0.2)
		if self:isCarryingEgg() then
			collected = true
			break
		end
	end

	if collected then
		self.notify(string.format("🥚 Collected %s! Returning to base...", target.eggName or target.petName or "Egg"), "success")
		if self.returnToBase then
			local basePos = self:findBasePosition()
			if basePos then
				if self.movementElevation and self.movementElevation > 0 then
					glideTo(Vector3.new(basePos.X, math.max(eggPos.Y, basePos.Y) + self.movementElevation, basePos.Z), 10)
				end
				glideTo(basePos + Vector3.new(0, 0.5, 0), 10)

				local depositPrompt = self:findNearbyPrompt(basePos, 15)
				if depositPrompt then
					self:triggerPrompt(depositPrompt)
				end

				local depDeadline = os.clock() + 1.8
				while os.clock() < depDeadline and self:isCarryingEgg() and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
					task.wait(0.1)
				end
			end
		end

		self:logEggStolen(target)
		return true
	else
		self.notify(string.format("⚠️ Missed %s (taken or prompt failed). Skipping...", target.eggName or target.petName or "Egg"), "warning")
		return false
	end
end

function Movement:instantTeleportSteal(target)
	local hum, root = self:_context()
	if not hum or not root or hum.Health <= 0 then
		return false
	end

	local char = LocalPlayer.Character
	local targetCF = CFrame.new(target.position + Vector3.new(0, 1.5, 0))
	teleportCharacter(char, targetCF)
	task.wait(0.08)

	local curHumT, curRootT = self:_context()
	if not curRootT or (curRootT.Position - target.position).Magnitude > 14 then
		return false
	end

	local collected = false
	local deadline = os.clock() + 3.0
	while os.clock() < deadline and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
		self:stealEgg(target)
		task.wait(0.2)
		if self:isCarryingEgg() then
			collected = true
			break
		end
	end

	if collected then
		self.notify(string.format("🥚 Collected %s! Returning to base...", target.eggName or target.petName or "Egg"), "success")
		if self.returnToBase then
			local basePos = self:findBasePosition()
			if basePos then
				teleportCharacter(char, CFrame.new(basePos + Vector3.new(0, 0.5, 0)))

				local depositPrompt = self:findNearbyPrompt(basePos, 15)
				if depositPrompt then
					self:triggerPrompt(depositPrompt)
				end

				local depDeadline = os.clock() + 1.8
				while os.clock() < depDeadline and self:isCarryingEgg() and (self.autoFarmBestRunning or self.autoFarmAllRunning) do
					task.wait(0.1)
				end
			end
		end

		self:logEggStolen(target)
		return true
	else
		self.notify(string.format("⚠️ Missed %s (taken or prompt failed). Skipping...", target.eggName or target.petName or "Egg"), "warning")
		return false
	end
end

function Movement:executeAutoSteal(target)
	local mode = self.movementMode or "Tween"
	if mode == "Tween" then
		return self:tweenSteal(target)
	elseif mode == "Walk (Pathfinding)" then
		return self:walkSteal(target)
	elseif mode == "CFrame Glide" then
		return self:glideSteal(target)
	elseif mode == "Instant Teleport" then
		return self:instantTeleportSteal(target)
	else
		return self:exploitSteal(target)
	end
end

-- Auto Farm (Best Eggs Only): Respects minMoneyPerSec, exploit steal & spawn wait
function Movement:toggleAutoFarmBest(enabled)
	if not enabled then
		self.autoFarmBestRunning = false
		local hum = Util.getHumanoid()
		if hum then hum.WalkSpeed = 16 end
		self.notify("Auto Steal stopped", "info")
		return
	end

	self.autoFarmAllRunning = false
	self.autoFarmBestRunning = true
	self:neutralizeAntiCheat()
	self.notify(string.format("Auto Steal active • Mode: %s • Min: %s • Speed %d", self.movementMode or "Tween", EggData.formatMoney(self.minMoneyPerSec), self.customSpeed), "success")

	Util.spawn(function()
		local waitingAtSpawn = false
		while self.autoFarmBestRunning do
			-- Wait for a live character before doing anything
			if not self:_waitForCharacter(8) then
				task.wait(1)
				continue
			end

			local hum, root = self:_context()
			if not hum or not root or hum.Health <= 0 then
				task.wait(1)
				continue
			end

			-- After respawn, move to safe centre so we don't walk into walls
			self:_handleRespawn()

			-- 1. Find best egg meeting minimum money threshold (e.g. >= 1M/s)
			local target = EggData.bestValue(self.minMoneyPerSec)
			if not target then
				-- No eggs meeting the threshold currently on the map: keep player at spawn
				local basePos = self:findBasePosition()
				if basePos then
					local distToBase = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(basePos.X, 0, basePos.Z)).Magnitude
					if distToBase > 15 then
						pcall(function()
							root.CFrame = CFrame.new(basePos + Vector3.new(0, 3, 0))
						end)
					end
				end

				if not waitingAtSpawn then
					waitingAtSpawn = true
					if self.minMoneyPerSec > 0 then
						self.notify(string.format("Waiting at spawn for eggs >= %s to respawn...", EggData.formatMoney(self.minMoneyPerSec)), "info")
					else
						self.notify("Waiting at spawn for eggs to spawn...", "info")
					end
				end

				task.wait(1.5)
				continue
			end

			-- Target found! Reset spawn wait flag
			waitingAtSpawn = false

			-- 2. Execute auto steal sequence using selected movement system
			local ok = self:executeAutoSteal(target)
			if not ok then
				task.wait(0.5)
			else
				task.wait(0.3)
			end
		end
	end)
end

-- Auto Farm (All Eggs Nearest-First): Respects minMoneyPerSec, exploit steal & spawn wait
function Movement:toggleAutoFarmAll(enabled)
	if not enabled then
		self.autoFarmAllRunning = false
		local hum = Util.getHumanoid()
		if hum then hum.WalkSpeed = 16 end
		self.notify("Auto Farm (All) stopped", "info")
		return
	end

	self.autoFarmBestRunning = false
	self.autoFarmAllRunning = true
	self:neutralizeAntiCheat()
	self.notify(string.format("Auto Farm (All) active • Mode: %s • Min: %s • Speed %d", self.movementMode or "Tween", EggData.formatMoney(self.minMoneyPerSec), self.customSpeed), "success")

	Util.spawn(function()
		local waitingAtSpawn = false
		while self.autoFarmAllRunning do
			-- Wait for a live character before doing anything
			if not self:_waitForCharacter(8) then
				task.wait(1)
				continue
			end

			local hum, root = self:_context()
			if not hum or not root or hum.Health <= 0 then
				task.wait(1)
				continue
			end

			-- After respawn, move to safe centre so we don't walk into walls
			self:_handleRespawn()

			local target = EggData.closest(nil, self.minMoneyPerSec)
			if not target then
				local basePos = self:findBasePosition()
				if basePos then
					local distToBase = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(basePos.X, 0, basePos.Z)).Magnitude
					if distToBase > 15 then
						pcall(function()
							root.CFrame = CFrame.new(basePos + Vector3.new(0, 3, 0))
						end)
					end
				end

				if not waitingAtSpawn then
					waitingAtSpawn = true
					if self.minMoneyPerSec > 0 then
						self.notify(string.format("Waiting at spawn for eggs >= %s to respawn...", EggData.formatMoney(self.minMoneyPerSec)), "info")
					else
						self.notify("Waiting at spawn for eggs to spawn...", "info")
					end
				end

				task.wait(1.5)
				continue
			end

			waitingAtSpawn = false

			local ok = self:executeAutoSteal(target)
			if not ok then
				task.wait(0.5)
			else
				task.wait(0.3)
			end
		end
	end)
end

-- Finds the offline income collector Part/Prompt inside the player's plot
local function findOfflinePile()
	-- Search for the cash pile / offline earnings collector in the plot
	-- Common names: "OfflinePile", "AwayCash", "OfflineIncome", "CashPile", "Earnings"
	local plotsFolder = workspace:FindFirstChild("Plots")
		or workspace:FindFirstChild("PlayerPlots")
		or workspace:FindFirstChild("Plots", true)

	local function searchIn(parent)
		if not parent then return nil end
		for _, desc in ipairs(parent:GetDescendants()) do
			local lname = string.lower(desc.Name)
			if desc:IsA("BasePart") and (
				string.find(lname, "offline", 1, true) or
				string.find(lname, "awaycash", 1, true) or
				string.find(lname, "cashpile", 1, true) or
				string.find(lname, "earnings", 1, true) or
				string.find(lname, "moneystack", 1, true) or
				string.find(lname, "pile", 1, true)
			) then
				return desc
			end
			-- Also look for a ProximityPrompt whose ActionText mentions collecting
			if desc:IsA("ProximityPrompt") then
				local act = string.lower(desc.ActionText)
				if string.find(act, "collect", 1, true) or string.find(act, "claim", 1, true) or string.find(act, "cash", 1, true) then
					local pp = desc.Parent
					if pp and pp:IsA("BasePart") then return pp end
				end
			end
		end
		return nil
	end

	-- 1. Search inside the player's own plot
	if plotsFolder then
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			local owner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerName") or plot:GetAttribute("OwnerId")
			local isMatch = (owner == LocalPlayer.Name or owner == tostring(LocalPlayer.UserId) or owner == LocalPlayer.UserId)
			if isMatch then
				local found = searchIn(plot)
				if found then return found end
			end
		end
	end

	-- 2. Fall back: search entire workspace for the pile
	return searchIn(workspace)
end

-- Claim Offline Income: fast-walk to the income pile, collect, fast-walk back
function Movement:claimOfflineIncome()
	local root = Util.getRootPart()
	local hum = Util.getHumanoid()
	if not root or not hum then
		self.notify("Character not ready", "error")
		return false
	end

	local originalPos = root.Position
	local originalSpeed = hum.WalkSpeed

	-- Step 1: Find the offline income pile
	local pile = findOfflinePile()
	local pilePos = pile and pile.Position or nil

	-- Step 2: Temporarily boost speed and walk to the pile
	if pilePos then
		hum.WalkSpeed = 100
		-- Use a short dedicated walk loop (not safeWalkTo which checks farm flags)
		local deadline = os.clock() + 8
		while os.clock() < deadline do
			local curRoot = Util.getRootPart()
			local curHum = Util.getHumanoid()
			if not curRoot or not curHum then break end
			local dist = (Vector3.new(pilePos.X, 0, pilePos.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z)).Magnitude
			if dist <= 5 then break end
			curHum:MoveTo(pilePos)
			local velDir = (Vector3.new(pilePos.X, 0, pilePos.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z)).Unit
			pcall(function()
				local velY = curRoot.AssemblyLinearVelocity.Y
				curRoot.AssemblyLinearVelocity = Vector3.new(velDir.X * 100, velY, velDir.Z * 100)
			end)
			task.wait(0.12)
		end
		task.wait(0.3)
	end

	-- Step 3: Fire all collection methods now that we're standing at the pile
	local claimed = false
	local amount = nil

	-- Method A: RF/AwayEarnings/AskCollect remote
	pcall(function()
		local networking = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
		local rfAway = (networking and networking:FindFirstChild("RF/AwayEarnings/AskCollect"))
			or ReplicatedStorage:FindFirstChild("RF/AwayEarnings/AskCollect", true)
		if rfAway and rfAway:IsA("RemoteFunction") then
			local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
			local platformController = playerScripts and playerScripts:FindFirstChild("Game") and playerScripts.Game:FindFirstChild("PlatformController")
			local result = nil
			if platformController then
				result = rfAway:InvokeServer(platformController)
			else
				result = rfAway:InvokeServer()
			end
			if result then
				claimed = true
				if type(result) == "table" and result[3] and result[3].AwardedAmount then
					amount = result[3].AwardedAmount
				end
			end
		end
	end)

	-- Method B: Trigger nearby collect/claim ProximityPrompts
	pcall(function()
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("ProximityPrompt") then
				local act = string.lower(desc.ActionText)
				if string.find(act, "collect", 1, true) or string.find(act, "claim", 1, true) or string.find(act, "cash", 1, true) then
					if fireproximityprompt then
						pcall(fireproximityprompt, desc, 0, true)
					else
						pcall(function() desc:InputHoldBegin() task.wait(0.15) desc:InputHoldEnd() end)
					end
					claimed = true
				end
			end
		end
	end)

	-- Method C: firetouchinterest on the pile
	if pile then
		pcall(function()
			local curRoot = Util.getRootPart()
			if curRoot and firetouchinterest then
				firetouchinterest(curRoot, pile, 0)
				task.wait(0.1)
				firetouchinterest(curRoot, pile, 1)
				claimed = true
			end
		end)
	end

	task.wait(0.2)

	-- Step 4: Walk back to original position at same fast speed
	if originalPos then
		local deadline = os.clock() + 8
		while os.clock() < deadline do
			local curRoot = Util.getRootPart()
			local curHum = Util.getHumanoid()
			if not curRoot or not curHum then break end
			local dist = (Vector3.new(originalPos.X, 0, originalPos.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z)).Magnitude
			if dist <= 4 then break end
			curHum:MoveTo(originalPos)
			local velDir = (Vector3.new(originalPos.X, 0, originalPos.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z)).Unit
			pcall(function()
				local velY = curRoot.AssemblyLinearVelocity.Y
				curRoot.AssemblyLinearVelocity = Vector3.new(velDir.X * 100, velY, velDir.Z * 100)
			end)
			task.wait(0.12)
		end
	end

	-- Restore original speed
	local curHum = Util.getHumanoid()
	if curHum then curHum.WalkSpeed = originalSpeed end

	if claimed and amount then
		self.notify(string.format("Claimed offline income: +%s!", EggData.formatMoney(amount)), "success")
	elseif claimed then
		self.notify("Claimed offline income successfully!", "success")
	else
		self.notify("Walked to pile — no income available yet", "info")
	end
	return claimed
end


-- Auto Collect Offline Cash (loops every 5s, teleports to pile each time)
function Movement:toggleAutoCash(enabled)
	if not enabled then
		self.autoCashRunning = false
		self.notify("Auto Cash stopped", "info")
		return
	end

	self.autoCashRunning = true
	self.notify("Auto Cash enabled — teleporting to pile every 5s", "success")

	Util.spawn(function()
		while self.autoCashRunning do
			pcall(function()
				self:claimOfflineIncome()
			end)
			task.wait(5)
		end
	end)
end

-- Auto Equip Best Pets
function Movement:equipBestPets()
	local success = false

	pcall(function()
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		if Remotes and Remotes.Haul and Remotes.Haul.WearBest then
			Remotes.Haul.WearBest:InvokeServer()
			success = true
		end
	end)

	if not success then
		pcall(function()
			for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
				if (desc:IsA("RemoteFunction") or desc:IsA("RemoteEvent")) and string.find(desc.Name, "WearBest", 1, true) then
					if desc:IsA("RemoteFunction") then
						desc:InvokeServer()
					else
						desc:FireServer()
					end
					success = true
					break
				end
			end
		end)
	end

	if success then
		self.notify("Equipped best pets successfully!", "success")
	else
		self.notify("WearBest remote executed or not available in this build", "info")
	end
end

-- Anti-Trap: Disables collision and touch detection on all traps without destroying internal engine instances
function Movement:toggleAntiTrap(enabled)
	if not enabled then
		self.antiTrapRunning = false
		self.notify("Anti-Trap disabled", "info")
		return
	end

	self.antiTrapRunning = true
	self.notify("Anti-Trap enabled - all traps neutralized", "success")

	Util.spawn(function()
		while self.antiTrapRunning do
			pcall(function()
				for _, trap in ipairs(CollectionService:GetTagged("PlacedTrap")) do
					if trap:IsA("BasePart") then
						trap.CanCollide = false
						trap.CanTouch = false
					elseif trap:IsA("Model") then
						for _, part in ipairs(trap:GetDescendants()) do
							if part:IsA("BasePart") then
								part.CanCollide = false
								part.CanTouch = false
							end
						end
					end
				end
				for _, inst in ipairs(workspace:GetDescendants()) do
					if string.find(string.lower(inst.Name), "trap", 1, true) and inst:IsA("BasePart") then
						inst.CanCollide = false
						inst.CanTouch = false
					end
				end
			end)
			task.wait(1)
		end
	end)
end

-- Monster / Guard Bypass: Disables enemy collision and hitboxes
function Movement:toggleMonsterBypass(enabled)
	if not enabled then
		self.monsterBypassRunning = false
		self.notify("Monster bypass disabled", "info")
		return
	end

	self.monsterBypassRunning = true
	self.notify("Monster bypass enabled - guards frozen & neutralized", "success")

	Util.spawn(function()
		while self.monsterBypassRunning do
			pcall(function()
				for _, model in ipairs(workspace:GetDescendants()) do
					if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") and model ~= Util.getCharacter() then
						local name = string.lower(model.Name)
						if string.find(name, "guard", 1, true) or string.find(name, "monster", 1, true) or string.find(name, "enemy", 1, true) or string.find(name, "npc", 1, true) then
							local enemyHum = model:FindFirstChildOfClass("Humanoid")
							if enemyHum then
								enemyHum.WalkSpeed = 0
							end
							for _, part in ipairs(model:GetDescendants()) do
								if part:IsA("BasePart") then
									part.CanCollide = false
									part.CanTouch = false
								end
							end
						end
					end
				end
			end)
			task.wait(1.5)
		end
	end)
end

-- Anti Hit Guard: Active forcefield repellent, disables guard collision/touch, and completely blocks knockback & egg dropping
function Movement:toggleAntiGuardHit(enabled)
	if not enabled then
		self.antiGuardHitRunning = false
		if self.connections.antiGuardStepped then
			self.connections.antiGuardStepped:Disconnect()
			self.connections.antiGuardStepped = nil
		end
		self.notify("Anti Hit Guard disabled", "info")
		return
	end

	self.antiGuardHitRunning = true
	-- Automatically engage anti-ragdoll and anti-knockback
	self:toggleAntiRagdoll(true)
	self:toggleAntiKnockback(true)
	self.notify("Anti Hit Guard active — fast guards blocked & frozen", "success")

	-- Initial proactive freeze on all existing guards
	pcall(function()
		local obj = workspace:FindFirstChild("__OBJECTS")
		local areas = obj and obj:FindFirstChild("Areas")
		local guardAreas = areas and areas:FindFirstChild("GuardAreas")
		if guardAreas then
			for _, d in ipairs(guardAreas:GetDescendants()) do
				if d:IsA("Model") and (d.Name == "Guard" or string.find(string.lower(d.Name), "guard", 1, true)) then
					local gHum = d:FindFirstChildOfClass("Humanoid")
					if gHum then gHum.WalkSpeed = 0 end
					local gRoot = d:FindFirstChild("HumanoidRootPart") or d:FindFirstChildWhichIsA("BasePart")
					if gRoot then gRoot.Anchored = true end
					for _, p in ipairs(d:GetDescendants()) do
						if p:IsA("BasePart") then
							p.CanTouch = false
							p.CanCollide = false
						end
					end
				end
			end
		end
	end)

	if not self.connections.antiGuardStepped then
		self.connections.antiGuardStepped = RunService.Stepped:Connect(function()
			if not self.antiGuardHitRunning then return end

			local char = LocalPlayer.Character
			local playerRoot = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not playerRoot or not hum then return end

			-- Keep player immune to stun / ragdoll
			hum.PlatformStand = false

			-- Helper to completely neutralize any guard model
			local function neutralizeGuard(guard)
				if not guard or not guard:IsA("Model") or guard == char then return end

				local guardRoot = guard:FindFirstChild("HumanoidRootPart") or guard:FindFirstChildWhichIsA("BasePart")
				if guardRoot and playerRoot then
					local diff = (guardRoot.Position - playerRoot.Position)
					local dist = diff.Magnitude

					-- Active Repulsion Field: if any fast guard enters within 35 studs, push them away horizontally along ground level (NO dropping underground!)
					if dist < 35 then
						local pushDir = Vector3.new(diff.X, 0, diff.Z)
						if pushDir.Magnitude > 0.01 then
							pushDir = pushDir.Unit
						else
							pushDir = Vector3.new(0, 0, 1)
						end
						pcall(function()
							-- Keep natural Y coordinate so GuardMovementRecovery never triggers
							local groundY = guardRoot.Position.Y
							guard:PivotTo(CFrame.new(playerRoot.Position.X + pushDir.X * 50, groundY, playerRoot.Position.Z + pushDir.Z * 50))
							guardRoot.Anchored = true
						end)
					end
				end

				-- Freeze humanoid and set PlatformStand so guard goes limp and cannot attack
				local gHum = guard:FindFirstChildOfClass("Humanoid")
				if gHum then
					if gHum.WalkSpeed > 0 then
						gHum.WalkSpeed = 0
					end
					gHum.PlatformStand = true
				end

				-- Disable touch and collision on all guard parts (weapons, bats, limbs)
				for _, part in ipairs(guard:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanTouch = false
						part.CanCollide = false
					end
				end
			end

			-- 1. Targeted deep search across all GuardAreas (covers Light Dark, Cosmic, Lake, Forest, Desert, etc.)
			local obj = workspace:FindFirstChild("__OBJECTS")
			local areas = obj and obj:FindFirstChild("Areas")
			local guardAreas = areas and areas:FindFirstChild("GuardAreas")
			if guardAreas then
				for _, desc in ipairs(guardAreas:GetDescendants()) do
					if desc:IsA("Model") and (desc.Name == "Guard" or string.find(string.lower(desc.Name), "guard", 1, true)) then
						neutralizeGuard(desc)
					end
				end
			end

			-- 2. General workspace check for any Guard models
			for _, m in ipairs(workspace:GetDescendants()) do
				if m:IsA("Model") and (m.Name == "Guard" or string.find(string.lower(m.Name), "guard", 1, true)) and m ~= char then
					neutralizeGuard(m)
				end
			end
		end)
	end
end

-- Anti-Ragdoll: Prevents falling down or ragdoll stun
function Movement:toggleAntiRagdoll(enabled)
	if not enabled then
		self.antiRagdollRunning = false
		self.notify("Anti-Ragdoll disabled", "info")
		return
	end

	self.antiRagdollRunning = true
	self.notify("Anti-Ragdoll enabled - immune to knockdowns", "success")

	Util.spawn(function()
		while self.antiRagdollRunning do
			local hum = Util.getHumanoid()
			if hum then
				pcall(function()
					hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
					hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
					hum.PlatformStand = false
				end)
			end
			task.wait(0.75)
		end
	end)
end

-- Anti-Knockback: Clamps horizontal velocity impulses so bat hits and animal attacks cannot launch or drop the egg
function Movement:toggleAntiKnockback(enabled)
	self.antiKnockbackRunning = enabled == true
	if self.antiKnockbackRunning then
		self.notify("Anti-Knockback enabled", "success")
		if not self.connections.antiKnockback then
			self.connections.antiKnockback = RunService.Stepped:Connect(function()
				if self.antiKnockbackRunning then
					local char = LocalPlayer.Character
					local pRoot = char and char:FindFirstChild("HumanoidRootPart")
					if pRoot then
						local vel = pRoot.AssemblyLinearVelocity
						local maxAllowed = math.max((self.customSpeed or 60) + 20, 50)
						local horizSpeed = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
						if horizSpeed > maxAllowed then
							local factor = maxAllowed / horizSpeed
							pRoot.AssemblyLinearVelocity = Vector3.new(vel.X * factor, vel.Y, vel.Z * factor)
						end
					end
				end
			end)
		end
	else
		if self.connections.antiKnockback then
			self.connections.antiKnockback:Disconnect()
			self.connections.antiKnockback = nil
		end
		self.notify("Anti-Knockback disabled", "info")
	end
end

-- Diagnostics: Dumps all Remotes, GuardAreas, and Player attributes to F9 console
function Movement:dumpDiagnostics()
	print("================== [FROST DIAGNOSTICS] ==================")
	local networking = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
	if networking then
		print("--- Packages.Networking Remotes ---")
		for _, child in ipairs(networking:GetChildren()) do
			print(string.format("  [%s] %s", child.ClassName, child.Name))
		end
	else
		print("--- Packages.Networking: NOT FOUND ---")
	end

	local obj = workspace:FindFirstChild("__OBJECTS")
	local areas = obj and obj:FindFirstChild("Areas")
	local guardAreas = areas and areas:FindFirstChild("GuardAreas")
	if guardAreas then
		print("--- GuardAreas & Guards ---")
		for _, area in ipairs(guardAreas:GetChildren()) do
			local guard = area:FindFirstChild("Guard") or area:FindFirstChildWhichIsA("Model")
			if guard then
				local tools = {}
				for _, d in ipairs(guard:GetDescendants()) do
					if d:IsA("Tool") or string.find(string.lower(d.Name), "bat", 1, true) or string.find(string.lower(d.Name), "weapon", 1, true) then
						table.insert(tools, d.Name .. " (" .. d.ClassName .. ")")
					end
				end
				print(string.format("  Area: %s | Guard: %s | Tools: %s", area.Name, guard.Name, #tools > 0 and table.concat(tools, ", ") or "None"))
			end
		end
	else
		print("--- GuardAreas: NOT FOUND ---")
	end

	local char = LocalPlayer.Character
	if char then
		print("--- Player Character Attributes ---")
		for k, v in pairs(char:GetAttributes()) do
			print(string.format("  Attribute: %s = %s", tostring(k), tostring(v)))
		end
	end

	print("--- Carried Egg Status ---")
	print(string.format("  isCarryingEgg(): %s", tostring(self:isCarryingEgg())))
	if eggStateModule then
		print("--- EggState Module Members ---")
		for k, v in pairs(eggStateModule) do
			print(string.format("  [%s] %s", type(v), tostring(k)))
		end
	end
	print("==========================================================")
	self.notify("Diagnostic dump printed to F9 console!", "info")
end

-- Auto Treadmill: Trains speed automatically on plot treadmill
function Movement:toggleAutoTreadmill(enabled)
	if not enabled then
		self.autoTreadmillRunning = false
		self.notify("Auto Treadmill stopped", "info")
		return
	end
	self.autoTreadmillRunning = true
	self.notify("Auto Treadmill active - training speed", "success")

	Util.spawn(function()
		while self.autoTreadmillRunning do
			local treadmill = workspace:FindFirstChild("Treadmill", true)
			if treadmill then
				local hum = Util.getHumanoid()
				local root = Util.getRootPart()
				local tPos = EggData.worldPositionOf(treadmill)
				if hum and root and tPos then
					local dist = (Vector3.new(tPos.X, 0, tPos.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
					if dist > 6 then
						hum:MoveTo(tPos)
					else
						hum:Move(Vector3.new(0, 0, -1), true)
					end
				end
			end
			task.wait(0.5)
		end
	end)
end

function Movement:stop()
	if self._currentTween then
		pcall(function()
			self._currentTween:Cancel()
		end)
		self._currentTween = nil
	end
	pcall(function()
		local root = Util.getRootPart()
		local hum = Util.getHumanoid()
		if root then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
		end
		if hum then
			hum.PlatformStand = false
		end
	end)
	self.autoFarmAllRunning = false
	self.autoFarmBestRunning = false
	self.autoCashRunning = false
	self.antiTrapRunning = false
	self.monsterBypassRunning = false
	self.antiRagdollRunning = false
	self.antiKnockbackRunning = false
	self.autoTreadmillRunning = false
	self.speedBypassRunning = false
	self.busy = false
	for _, c in pairs(self.connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	self.connections = {}
end

return Movement
