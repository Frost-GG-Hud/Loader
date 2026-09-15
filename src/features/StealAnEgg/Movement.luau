-- Teleporting and walking.
--
-- Bugs fixed from the original:
--  * "Auto Farm" and "Best Egg Auto-Collect" moved the player by assigning
--    `HumanoidRootPart.CFrame` every 0.3s, which ignores collision entirely -
--    the character rammed through walls, clipped into geometry and produced no
--    walk animation. They now drive Humanoid:MoveTo;
--  * a single `MoveTo` was issued and then waited on for 15s, so one blocked
--    step wasted the whole budget. The destination is re-issued on a timer and
--    the walk bails out early when it stops making progress;
--  * the walk speed boost was only applied if the character existed at that
--    exact moment and was never restored on early return.

local ctx = ...
local Util = ctx.require("core/Util")
local EggData = ctx.require("features/StealAnEgg/EggData")

local Players = game:GetService("Players")

local STEP_INTERVAL = 0.35
local AUTO_INTERVAL = 0.5
local AUTO_RANGE = 45
local BOOST_SPEED = 300
local ARRIVE_DISTANCE = 6
local STALL_LIMIT = 8
local WALK_TIMEOUT = 25
local SAFE_ZONE_NAMES = { "SafeZone", "SafeArea", "Base", "Baseplate", "SpawnArea" }

local Movement = {}
Movement.__index = Movement

function Movement.new(config)
	return setmetatable({
		notify = config.notify,
		autoRange = config.autoRange or AUTO_RANGE,
		boostSpeed = config.boostSpeed or BOOST_SPEED,
		autoRunning = false,
		busy = false,
	}, Movement)
end

function Movement:_context()
	local hum = Util.getHumanoid()
	local root = Util.getRootPart()
	if not hum or not root then
		self.notify("Character not ready", "error")
		return nil
	end
	return hum, root
end

function Movement:teleportToClosestEgg()
	local _, root = self:_context()
	if not root then
		return false
	end

	local target = EggData.closest(self.autoRange * 4)
	if not target then
		self.notify("No egg found nearby", "error")
		return false
	end

	root.CFrame = CFrame.new(target.position + Vector3.new(0, 4, 0))
	self.notify(string.format("Teleported to egg (%.0f studs away)", target.distance), "success")
	return true
end

function Movement:teleportToClosestPlayer()
	local _, root = self:_context()
	if not root then
		return false
	end

	local closestRoot = nil
	local closestDistance = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Players.LocalPlayer and player.Character then
			local otherRoot = player.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local distance = (otherRoot.Position - root.Position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestRoot = otherRoot
				end
			end
		end
	end

	if not closestRoot then
		self.notify("No other player found", "error")
		return false
	end

	root.CFrame = closestRoot.CFrame + Vector3.new(0, 5, 0)
	self.notify("Teleported to closest player", "success")
	return true
end

function Movement:findSafePosition()
	for _, name in ipairs(SAFE_ZONE_NAMES) do
		local found = workspace:FindFirstChild(name, true)
		if found then
			local position = EggData.worldPositionOf(found)
			if position then
				return position + Vector3.new(0, 4, 0)
			end
		end
	end

	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position + Vector3.new(0, 4, 0)
	end
	return nil
end

-- Walks to `position`, re-issuing the destination and giving up early if the
-- character stops making progress (stuck on geometry, wall, etc).
function Movement:walkTo(position, opts)
	opts = opts or {}
	local hum, root = self:_context()
	if not root then
		return false
	end

	local arriveDistance = opts.arriveDistance or ARRIVE_DISTANCE
	local timeout = opts.timeout or WALK_TIMEOUT
	local originalSpeed = hum.WalkSpeed
	hum.WalkSpeed = opts.speed or self.boostSpeed

	local deadline = os.clock() + timeout
	local lastDistance = math.huge
	local stalled = 0
	local arrived = false

	while os.clock() < deadline do
		if not hum.Parent or not root.Parent then
			break
		end

		local distance = (position - root.Position).Magnitude
		if distance <= arriveDistance then
			arrived = true
			break
		end

		if lastDistance - distance < 0.5 then
			stalled = stalled + 1
		else
			stalled = 0
		end
		lastDistance = distance

		if stalled >= STALL_LIMIT then
			break
		end

		hum:MoveTo(position)
		Util.wait(STEP_INTERVAL)
	end

	if hum.Parent then
		hum.WalkSpeed = originalSpeed
	end
	return arrived
end

function Movement:toggleAutoCollect(enabled)
	if not enabled then
		self.autoRunning = false
		local hum = Util.getHumanoid()
		if hum then
			hum:MoveTo(hum.RootPart and hum.RootPart.Position or Vector3.zero)
		end
		self.notify("Auto collect stopped", "info")
		return
	end

	if self.autoRunning then
		return
	end

	local hum, root = self:_context()
	if not hum or not root then
		return
	end

	self.autoRunning = true
	local originalSpeed = hum.WalkSpeed
	hum.WalkSpeed = self.boostSpeed

	Util.spawn(function()
		while self.autoRunning do
			local nearest = EggData.closest(self.autoRange)
			local currentHum = Util.getHumanoid()
			if not nearest or not currentHum then
				Util.wait(AUTO_INTERVAL)
			else
				currentHum:MoveTo(nearest.position)
				Util.wait(AUTO_INTERVAL)
			end
		end

		local finalHum = Util.getHumanoid()
		if finalHum and finalHum.Parent then
			finalHum.WalkSpeed = originalSpeed
		end
	end)

	self.notify("Auto collect enabled - walking to nearby eggs", "success")
end

function Movement:walkToBestEgg()
	if self.busy then
		self.notify("Already walking to an egg", "warning")
		return
	end

	local best = EggData.bestValue()
	if not best then
		self.notify("No unclaimed egg with a readable value. Try 'Scan Egg Attributes'.", "error")
		return
	end

	self.busy = true
	Util.spawn(function()
		self.notify(string.format("Walking to best egg (value %.0f)", best.value), "success")

		local arrived = self:walkTo(best.position)
		if not arrived then
			self.notify("Could not reach the egg (path blocked)", "warning")
		end

		-- Give the game a moment to register the pickup (Touch/ProximityPrompt/remote).
		Util.wait(0.6)

		local safePosition = self:findSafePosition()
		if safePosition then
			self.notify("Returning to spawn", "info")
			self:walkTo(safePosition)
		end

		self.busy = false
		self.notify("Done", "success")
	end)
end

function Movement:isBusy()
	return self.busy
end

function Movement:stop()
	self.autoRunning = false
	self.busy = false
end

return Movement
