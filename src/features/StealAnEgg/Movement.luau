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
		customSpeed = 60,
		minMoneyPerSec = 0,
		rememberedBasePos = nil,
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
	pcall(function()
		workspace:SetAttribute("ClientObbyAntiTp", false)
	end)

	-- 1. Hook RE/RigSync/CorrectionBegan to prevent client from alerting the server to rubberband
	pcall(function()
		local networking = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
		local reCorrection = networking and networking:FindFirstChild("RE/RigSync/CorrectionBegan")
		if reCorrection and hookfunction then
			hookfunction(reCorrection.FireServer, function(...)
				return nil
			end)
		end
	end)

	if hookmetamethod and not self._hookedCorrection then
		self._hookedCorrection = true
		pcall(function()
			local oldNamecall
			local badgeService = game:GetService("BadgeService")
			oldNamecall = hookmetamethod(game, "__namecall", function(selfObj, ...)
				local method = getnamecallmethod()
				if (method == "FireServer" or method == "fireServer") and not checkcaller() then
					if selfObj then
						local name = tostring(selfObj.Name)
						-- 1. Block anti-cheat rubberband position rollback
						if name == "RE/RigSync/CorrectionBegan" or string.find(name, "CorrectionBegan", 1, true) then
							return nil
						end
						-- 2. Block disguised BadgeService GUID telemetry beacons
						if badgeService and selfObj.Parent == badgeService then
							return nil
						end
						-- 3. Block guard hit/rouse triggers if anti-guard is active
						if (name == "RE/GuardPatrol/Rouse" or string.find(name, "GuardPatrol", 1, true)) and self.antiGuardHitRunning then
							return nil
						end
					end
				end
				return oldNamecall(selfObj, ...)
			end)
		end)
	end

	local function clean(parent)
		if not parent then return end
		for _, desc in ipairs(parent:GetDescendants()) do
			if desc:IsA("LocalScript") and (string.find(desc.Name, "AntiTP", 1, true) or string.find(desc.Name, "AntiTp", 1, true) or string.find(desc.Name, "RigSync", 1, true)) then
				desc.Disabled = true
				pcall(function() desc:Destroy() end)
			end
		end
	end

	pcall(function() clean(LocalPlayer:FindFirstChild("PlayerScripts")) end)
	pcall(function() clean(LocalPlayer.Character) end)
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

function Movement:toggleSpeedBypass(enabled)
	self.speedBypassRunning = enabled == true
	if self.speedBypassRunning then
		self:neutralizeAntiCheat()
		local hum, root = self:_context()
		if hum then
			hum.WalkSpeed = self.customSpeed
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

				if currentHum.WalkSpeed ~= self.customSpeed then
					currentHum.WalkSpeed = self.customSpeed
				end

				if not self.autoFarmAllRunning and not self.autoFarmBestRunning then
					local moveDir = currentHum.MoveDirection
					if moveDir.Magnitude > 0 then
						local speed = self.customSpeed
						local velY = currentRoot.AssemblyLinearVelocity.Y
						currentRoot.AssemblyLinearVelocity = Vector3.new(moveDir.X * speed, velY, moveDir.Z * speed)
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
	if not self.webhookEnabled or not self.webhookUrl or self.webhookUrl == "" then
		return
	end

	local cleanDisplay = entry.cleanDisplay or string.format("(%s) %s", entry.eggName or "Normal Egg", entry.petName or "Chicken")
	local moneyText = entry.moneyText or "+$50/s"
	local rarity = entry.rarity or "Common"

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
		if ok and plot and plot:IsA("Instance") then
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

		-- Apply linear velocity boost in goal direction
		local goalDelta = (Vector3.new(currentGoal.X, 0, currentGoal.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z))
		if speed > 20 and goalDelta.Magnitude > 2 then
			local velY = curRoot.AssemblyLinearVelocity.Y
			curRoot.AssemblyLinearVelocity = Vector3.new(goalDelta.Unit.X * speed, velY, goalDelta.Unit.Z * speed)
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

-- -- Steals an egg by directly invoking RF/EggWorld/AskFieldEggCarry and triggering ProximityPrompt
function Movement:stealEgg(targetEntry)
	local _, root = self:_context()
	if not root or not targetEntry then
		return false
	end

	local eggUid = targetEntry.uid
	local eggModel = targetEntry.model or targetEntry.instance
	local slotKey = targetEntry.slotKey

	-- 1. Direct invocation of RF/EggWorld/AskFieldEggCarry
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
				pcall(function() rfCarry:InvokeServer(eggModel) end)
			end
		end
	end)

	-- 2. Fast ProximityPrompt trigger
	local prompt = targetEntry.prompt
	if not prompt and eggModel and eggModel:IsA("Instance") then
		prompt = EggData.getPrompt(eggModel)
	end
	if not prompt and targetEntry.instance and targetEntry.instance:IsA("Instance") then
		prompt = EggData.getPrompt(targetEntry.instance)
	end

	if prompt and prompt:IsA("ProximityPrompt") then
		if fireproximityprompt then
			pcall(fireproximityprompt, prompt, 0, true)
		end

		pcall(function()
			prompt:InputHoldBegin()
			task.wait(0.12)
			prompt:InputHoldEnd()
		end)
	else
		task.wait(0.15)
	end

	if eggStateModule and eggStateModule.CarryFieldEgg and eggUid then
		pcall(function()
			eggStateModule.CarryFieldEgg(eggUid, slotKey)
		end)
	end

	return true
end

-- Auto Farm (Best Eggs Only): Respects minMoneyPerSec, walks at custom speed, recovers if trapped by animal
function Movement:toggleAutoFarmBest(enabled)
	if not enabled then
		self.autoFarmBestRunning = false
		local hum = Util.getHumanoid()
		if hum then hum.WalkSpeed = 16 end
		self.notify("Auto Farm (Best) stopped", "info")
		return
	end

	self.autoFarmAllRunning = false
	self.autoFarmBestRunning = true
	self:neutralizeAntiCheat()
	self.notify(string.format("Auto Farm (Best) active • Speed %d • Min: %s", self.customSpeed, EggData.formatMoney(self.minMoneyPerSec)), "success")

	Util.spawn(function()
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

			-- 1. Find best egg meeting minimum money threshold
			local target = EggData.bestValue(self.minMoneyPerSec)
			if not target then
				task.wait(1.5)
				continue
			end

			-- 2. Walk to egg (PathfindingService wall avoidance)
			local reached, reason = self:safeWalkTo(target.position, 20)
			if not self.autoFarmBestRunning then break end
			if reason == "trapped" then
				continue
			end

			-- 3. Only steal if we actually arrived close enough
			local curRoot = Util.getRootPart()
			if curRoot then
				local dist = (Vector3.new(target.position.X, 0, target.position.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z)).Magnitude
				if dist > 10 then
					-- Didn't get close enough – retry next cycle
					task.wait(0.5)
					continue
				end
			end

			-- 4. Steal egg (hold E / fire carry remote)
			self:stealEgg(target)
			task.wait(0.6)   -- let server-side grab register before walking off

			-- 5. Walk back to player's base plot to deposit
			local basePos = self:findBasePosition()
			local deposited, depReason = self:safeWalkTo(basePos, 22)
			if not self.autoFarmBestRunning then break end
			if not deposited and depReason == "trapped" then
				self.notify("Animal attacked during delivery! Waiting...", "warning")
				while self:isTrapped() and self.autoFarmBestRunning do
					task.wait(0.5)
				end
				continue
			end

			self:logEggStolen(target)
			task.wait(0.4)
		end
	end)
end

-- Auto Farm (All Eggs Nearest-First): Respects minMoneyPerSec, walks at custom speed, recovers if trapped
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
	self.notify(string.format("Auto Farm (All) active • Speed %d • Min: %s", self.customSpeed, EggData.formatMoney(self.minMoneyPerSec)), "success")

	Util.spawn(function()
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
				task.wait(1.5)
				continue
			end

			-- 1. Walk to egg (PathfindingService wall avoidance)
			local reached, reason = self:safeWalkTo(target.position, 18)
			if not self.autoFarmAllRunning then break end
			if reason == "trapped" then
				continue
			end

			-- 2. Only steal if we actually arrived close enough
			local curRoot = Util.getRootPart()
			if curRoot then
				local dist = (Vector3.new(target.position.X, 0, target.position.Z) - Vector3.new(curRoot.Position.X, 0, curRoot.Position.Z)).Magnitude
				if dist > 10 then
					task.wait(0.5)
					continue
				end
			end

			-- 3. Steal egg (hold E / fire carry remote)
			self:stealEgg(target)
			task.wait(0.6)   -- let server-side grab register before walking off

			-- 4. Walk to base to deposit
			local basePos = self:findBasePosition()
			local deposited, depReason = self:safeWalkTo(basePos, 20)
			if not self.autoFarmAllRunning then break end
			if not deposited and depReason == "trapped" then
				self.notify("Animal attacked during delivery! Waiting...", "warning")
				while self:isTrapped() and self.autoFarmAllRunning do
					task.wait(0.5)
				end
				continue
			end

			self:logEggStolen(target)
			task.wait(0.4)
		end
	end)
end

-- Claim Offline Income via RF/AwayEarnings/AskCollect
function Movement:claimOfflineIncome()
	local claimed = false
	local amount = nil
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

			if result and type(result) == "table" then
				claimed = true
				if result[3] and result[3].AwardedAmount then
					amount = result[3].AwardedAmount
				end
			end
		end
	end)

	if claimed and amount then
		self.notify(string.format("Claimed offline income: +%s!", EggData.formatMoney(amount)), "success")
	elseif claimed then
		self.notify("Claimed offline income successfully!", "success")
	else
		self.notify("No offline income currently available to claim", "info")
	end
	return claimed
end

-- Auto Collect Offline Cash
function Movement:toggleAutoCash(enabled)
	if not enabled then
		self.autoCashRunning = false
		self.notify("Auto Cash stopped", "info")
		return
	end

	self.autoCashRunning = true
	self.notify("Auto Cash enabled (using PlatformController remote)", "success")

	Util.spawn(function()
		while self.autoCashRunning do
			pcall(function()
				-- Method 1: Packages.Networking RF/AwayEarnings/AskCollect with PlatformController
				local networking = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Networking")
				local rfAway = (networking and networking:FindFirstChild("RF/AwayEarnings/AskCollect"))
					or ReplicatedStorage:FindFirstChild("RF/AwayEarnings/AskCollect", true)
				if rfAway and rfAway:IsA("RemoteFunction") then
					local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
					local platformController = playerScripts and playerScripts:FindFirstChild("Game") and playerScripts.Game:FindFirstChild("PlatformController")
					if platformController then
						rfAway:InvokeServer(platformController)
					else
						rfAway:InvokeServer()
					end
				end

				-- Method 2: Sweep proximity prompts in plots
				local root = Util.getRootPart()
				if root then
					for _, desc in ipairs(workspace:GetDescendants()) do
						if desc:IsA("ProximityPrompt") and (string.find(string.lower(desc.ActionText), "collect", 1, true) or string.find(string.lower(desc.ActionText), "claim", 1, true)) then
							pcall(function()
								if fireproximityprompt then
									fireproximityprompt(desc, 0, true)
								else
									desc:InputHoldBegin()
									task.wait(0.2)
									desc:InputHoldEnd()
								end
							end)
						elseif desc:IsA("BasePart") and (string.find(string.lower(desc.Name), "collect", 1, true) or string.find(string.lower(desc.Name), "offline", 1, true)) then
							pcall(function()
								if firetouchinterest then
									firetouchinterest(root, desc, 0)
									task.wait()
									firetouchinterest(root, desc, 1)
								end
							end)
						end
					end
				end
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

-- Anti-Trap: Disables collision, touch detection, and touch transmitters on all traps
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
						local tt = trap:FindFirstChildWhichIsA("TouchTransmitter")
						if tt then pcall(function() tt:Destroy() end) end
					elseif trap:IsA("Model") then
						for _, part in ipairs(trap:GetDescendants()) do
							if part:IsA("BasePart") then
								part.CanCollide = false
								part.CanTouch = false
								local tt = part:FindFirstChildWhichIsA("TouchTransmitter")
								if tt then pcall(function() tt:Destroy() end) end
							end
						end
					end
				end
				for _, inst in ipairs(workspace:GetDescendants()) do
					if string.find(string.lower(inst.Name), "trap", 1, true) and inst:IsA("BasePart") then
						inst.CanCollide = false
						inst.CanTouch = false
						local tt = inst:FindFirstChildWhichIsA("TouchTransmitter")
						if tt then pcall(function() tt:Destroy() end) end
					end
				end
			end)
			task.wait(1)
		end
	end)
end

-- Monster / Guard Bypass: Disables enemy collision, hitboxes, and freezes them
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
						if string.find(name, "guard") or string.find(name, "monster") or string.find(name, "enemy") or string.find(name, "npc") then
							local enemyHum = model:FindFirstChildOfClass("Humanoid")
							if enemyHum then
								enemyHum.WalkSpeed = 0
							end
							for _, part in ipairs(model:GetDescendants()) do
								if part:IsA("BasePart") then
									part.CanCollide = false
									part.CanTouch = false
									local tt = part:FindFirstChildWhichIsA("TouchTransmitter")
									if tt then pcall(function() tt:Destroy() end) end
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

-- Anti Hit Guard: Freezes guards in GuardAreas, disables touch hitboxes, and suppresses knockback interruptions
function Movement:toggleAntiGuardHit(enabled)
	if not enabled then
		self.antiGuardHitRunning = false
		self.notify("Anti Hit Guard disabled", "info")
		return
	end

	self.antiGuardHitRunning = true
	self.notify("Anti Hit Guard enabled - guards frozen & carry knockback blocked", "success")

	Util.spawn(function()
		while self.antiGuardHitRunning do
			pcall(function()
				-- 1. Targeted search in workspace.__OBJECTS.Areas.GuardAreas
				local obj = workspace:FindFirstChild("__OBJECTS")
				local areas = obj and obj:FindFirstChild("Areas")
				local guardAreas = areas and areas:FindFirstChild("GuardAreas")
				if guardAreas then
					for _, area in ipairs(guardAreas:GetChildren()) do
						for _, desc in ipairs(area:GetDescendants()) do
							if desc:IsA("Model") and (desc.Name == "Guard" or desc:FindFirstChildOfClass("Humanoid")) then
								local hum = desc:FindFirstChildOfClass("Humanoid")
								if hum then
									hum.WalkSpeed = 0
								end
								for _, p in ipairs(desc:GetDescendants()) do
									if p:IsA("BasePart") then
										p.CanCollide = false
										p.CanTouch = false
										local tt = p:FindFirstChildWhichIsA("TouchTransmitter")
										if tt then
											pcall(function() tt:Destroy() end)
										end
									end
								end
							end
						end
					end
				end

				-- 2. General guard fallback across workspace
				for _, model in ipairs(workspace:GetDescendants()) do
					if model:IsA("Model") and model ~= Util.getCharacter() and (string.find(string.lower(model.Name), "guard", 1, true) or model.Name == "Guard") then
						local hum = model:FindFirstChildOfClass("Humanoid")
						if hum then hum.WalkSpeed = 0 end
						for _, p in ipairs(model:GetDescendants()) do
							if p:IsA("BasePart") then
								p.CanCollide = false
								p.CanTouch = false
								local tt = p:FindFirstChildWhichIsA("TouchTransmitter")
								if tt then pcall(function() tt:Destroy() end) end
							end
						end
					end
				end
			end)
			task.wait(1.5)
		end
	end)
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

-- Anti-Knockback: Stops sudden violent physics velocity from animals and chickens
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
						if math.abs(vel.X) > 2000 or math.abs(vel.Z) > 2000 then
							pRoot.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
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
