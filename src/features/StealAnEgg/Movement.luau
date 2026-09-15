-- Movement, Automation, Traps & Guard Bypasses for Steal An Egg.

local ctx = ...
local Util = ctx.require("core/Util")
local EggData = ctx.require("features/StealAnEgg/EggData")

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local DEFAULT_RANGE = 250
local ARRIVE_DISTANCE = 5
local SAFE_ZONE_NAMES = { "SafeZone", "SafeArea", "Base", "Baseplate", "SpawnArea", "PlayerPlot", "Plot" }

local Movement = {}
Movement.__index = Movement

local function firePrompt(prompt)
	if not prompt then
		return false
	end
	if fireproximityprompt then
		pcall(fireproximityprompt, prompt, 0, true)
		return true
	end
	pcall(function()
		prompt:InputHoldBegin()
		task.wait(prompt.HoldDuration or 0.1)
		prompt:InputHoldEnd()
	end)
	return true
end

local function fireTouch(part1, part2)
	if not part1 or not part2 then
		return
	end
	if firetouchinterest then
		pcall(firetouchinterest, part1, part2, 0)
		task.wait()
		pcall(firetouchinterest, part1, part2, 1)
	end
end

function Movement.new(config)
	local self = setmetatable({
		notify = config.notify or function() end,
		autoFarmRunning = false,
		autoCashRunning = false,
		antiTrapRunning = false,
		monsterBypassRunning = false,
		antiRagdollRunning = false,
		autoEquipRunning = false,
		speedBoostRunning = false,
		customSpeed = 24,
		busy = false,
		connections = {},
	}, Movement)
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

function Movement:findBasePosition()
	-- Search for player's base plot
	local plots = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("PlayerPlots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local owner = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerName") or plot:GetAttribute("OwnerId")
			if owner == LocalPlayer.Name or owner == LocalPlayer.UserId then
				local deposit = plot:FindFirstChild("Deposit", true) or plot:FindFirstChild("EggPen", true) or plot:FindFirstChild("Base", true)
				if deposit then
					local pos = EggData.worldPositionOf(deposit)
					if pos then
						return pos + Vector3.new(0, 3, 0)
					end
				end
				local pos = EggData.worldPositionOf(plot)
				if pos then
					return pos + Vector3.new(0, 3, 0)
				end
			end
		end
	end

	-- Fallback to safe zones or spawn
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

function Movement:teleportTo(position)
	local _, root = self:_context()
	if not root or not position then
		return false
	end
	root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	return true
end

function Movement:teleportToBase()
	local basePos = self:findBasePosition()
	if self:teleportTo(basePos) then
		self.notify("Teleported to base / safe zone", "success")
		return true
	end
	return false
end

function Movement:teleportToClosestEgg()
	local closest = EggData.closest()
	if not closest then
		self.notify("No egg found in workspace", "error")
		return false
	end
	if self:teleportTo(closest.position) then
		self.notify(string.format("Teleported to %s (%.0f studs)", closest.rarity, closest.distance), "success")
		return true
	end
	return false
end

function Movement:teleportToBestEgg()
	local best = EggData.bestValue()
	if not best then
		self.notify("No egg found to teleport to", "error")
		return false
	end
	if self:teleportTo(best.position) then
		self.notify(string.format("Teleported to best egg (%s)", best.rarity), "success")
		return true
	end
	return false
end

function Movement:teleportToGearShop()
	local shop = workspace:FindFirstChild("GearShopStand", true) or workspace:FindFirstChild("Shop", true) or workspace:FindFirstChild("Stands", true)
	if shop then
		local pos = EggData.worldPositionOf(shop)
		if pos and self:teleportTo(pos) then
			self.notify("Teleported to Gear Shop", "success")
			return true
		end
	end
	self.notify("Gear shop not found in this map", "warning")
	return false
end

function Movement:teleportToClosestPlayer()
	local _, root = self:_context()
	if not root then
		return false
	end

	local closestPlayer = nil
	local closestDist = math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			local pRoot = p.Character:FindFirstChild("HumanoidRootPart")
			if pRoot then
				local dist = (pRoot.Position - root.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestPlayer = pRoot
				end
			end
		end
	end

	if closestPlayer then
		root.CFrame = closestPlayer.CFrame + Vector3.new(0, 4, 0)
		self.notify("Teleported to nearest player", "success")
		return true
	end

	self.notify("No other player found in server", "warning")
	return false
end

-- Grabs an egg instance (fires prompt, touch, or pulls egg part)
function Movement:grabEgg(targetEntry)
	local _, root = self:_context()
	if not root or not targetEntry then
		return false
	end

	local inst = targetEntry.instance
	if not inst or not inst.Parent then
		return false
	end

	-- 1. Check for ProximityPrompt
	local prompt = EggData.getPrompt(inst)
	if prompt then
		firePrompt(prompt)
	end

	-- 2. Check for TouchTransmitter or egg base part
	local eggPart = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
	if eggPart then
		fireTouch(root, eggPart)
		if not eggPart.Anchored then
			pcall(function()
				eggPart.CFrame = root.CFrame
				eggPart.CanCollide = false
			end)
		end
	end

	return true
end

-- Instant Steal: Teleport right to egg, fire grab, and return
function Movement:instantStealNearest()
	local _, root = self:_context()
	if not root then
		return false
	end

	local target = EggData.closest()
	if not target then
		self.notify("No egg available to steal", "error")
		return false
	end

	local prevPos = root.Position
	root.CFrame = CFrame.new(target.position + Vector3.new(0, 2, 0))
	task.wait(0.15)
	self:grabEgg(target)
	task.wait(0.2)
	self:grabEgg(target)
	self.notify(string.format("Grabbed %s!", target.name), "success")
	return true
end

-- Auto Farm: Runs loop to continuously find eggs, grab them, deposit them
function Movement:toggleAutoFarm(enabled, instantMode)
	if not enabled then
		self.autoFarmRunning = false
		self.notify("Auto Farm stopped", "info")
		return
	end

	if self.autoFarmRunning then
		return
	end

	self.autoFarmRunning = true
	self.notify("Auto Farm started - collecting and depositing eggs", "success")

	Util.spawn(function()
		while self.autoFarmRunning do
			local hum, root = self:_context()
			if not hum or not root then
				task.wait(1)
				continue
			end

			-- 1. Find best or nearest egg
			local target = EggData.bestValue() or EggData.closest()
			if not target then
				task.wait(0.75)
				continue
			end

			local basePos = self:findBasePosition()

			-- 2. Travel to egg
			if instantMode then
				root.CFrame = CFrame.new(target.position + Vector3.new(0, 3, 0))
				task.wait(0.2)
			else
				local dist = (target.position - root.Position).Magnitude
				if dist > 8 then
					hum:MoveTo(target.position)
					local deadline = os.clock() + 4
					while os.clock() < deadline and self.autoFarmRunning do
						local curRoot = Util.getRootPart()
						if not curRoot or (target.position - curRoot.Position).Magnitude <= ARRIVE_DISTANCE then
							break
						end
						task.wait(0.2)
					end
				end
			end

			-- 3. Grab egg
			self:grabEgg(target)
			task.wait(0.25)
			self:grabEgg(target)

			-- 4. Return to base/pen to deposit
			if instantMode then
				root.CFrame = CFrame.new(basePos)
			else
				hum:MoveTo(basePos)
				local deadline = os.clock() + 6
				while os.clock() < deadline and self.autoFarmRunning do
					local curRoot = Util.getRootPart()
					if not curRoot or (basePos - curRoot.Position).Magnitude <= ARRIVE_DISTANCE then
						break
					end
					task.wait(0.2)
				end
			end

			task.wait(0.5)
		end
	end)
end

-- Auto Collect Cash / Offline Earnings
function Movement:toggleAutoCash(enabled)
	if not enabled then
		self.autoCashRunning = false
		self.notify("Auto Cash stopped", "info")
		return
	end

	self.autoCashRunning = true
	self.notify("Auto Cash enabled", "success")

	Util.spawn(function()
		while self.autoCashRunning do
			pcall(function()
				-- Call game remote if exists
				local remotes = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Remotes")
					or ReplicatedStorage:FindFirstChild("Remotes")
				if remotes and remotes:FindFirstChild("AwayEarnings") and remotes.AwayEarnings:FindFirstChild("AskCollect") then
					remotes.AwayEarnings.AskCollect:InvokeServer()
				end

				-- Also scan for TouchTransmitter on cash stands
				local root = Util.getRootPart()
				if root then
					for _, part in ipairs(workspace:GetDescendants()) do
						if part:IsA("BasePart") and string.find(string.lower(part.Name), "collect", 1, true) then
							fireTouch(root, part)
						end
					end
				end
			end)
			task.wait(5)
		end
	end)
end

-- Auto Equip Best Pets for speed & multipliers
function Movement:equipBestPets()
	local ok, err = pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Remotes")
			or ReplicatedStorage:FindFirstChild("Remotes")
		if remotes and remotes:FindFirstChild("Haul") and remotes.Haul:FindFirstChild("WearBest") then
			remotes.Haul.WearBest:InvokeServer()
			self.notify("Equipped best pets!", "success")
			return true
		end
		self.notify("Pet remote not available", "warning")
		return false
	end)
	if not ok then
		self.notify("Could not equip pets: " .. tostring(err), "error")
	end
end

-- Anti-Trap: Disables collision and touch detection on all traps
function Movement:toggleAntiTrap(enabled)
	if not enabled then
		self.antiTrapRunning = false
		self.notify("Anti-Trap disabled", "info")
		return
	end

	self.antiTrapRunning = true
	self.notify("Anti-Trap enabled - traps bypassed", "success")

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
	self.notify("Monster bypass enabled - guards cannot hit you", "success")

	Util.spawn(function()
		while self.monsterBypassRunning do
			pcall(function()
				for _, model in ipairs(workspace:GetDescendants()) do
					if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") and model ~= Util.getCharacter() then
						local name = string.lower(model.Name)
						if string.find(name, "guard") or string.find(name, "monster") or string.find(name, "enemy") or string.find(name, "npc") then
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
				end)
			end
			task.wait(1)
		end
	end)
end

function Movement:stop()
	self.autoFarmRunning = false
	self.autoCashRunning = false
	self.antiTrapRunning = false
	self.monsterBypassRunning = false
	self.antiRagdollRunning = false
	self.busy = false
	for _, c in ipairs(self.connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	self.connections = {}
end

return Movement
