-- Universal features available in every game.
--
-- Bugs fixed from the original:
--  * Walkspeed/JumpPower were reset to hard-coded values (240/16, 100/50) on
--    toggle-off, clobbering whatever the game had set. They now restore the
--    value that was actually in effect;
--  * boosts were silently lost on respawn - enabled boosts are re-applied to
--    the new character;
--  * Fly zeroed AssemblyLinearVelocity every frame and left the humanoid in
--    PlatformStand, so turning it off dropped the player out of the sky with no
--    control. State is now restored properly;
--  * NoClip never restored collision - it now remembers each part's original
--    CanCollide and puts it back;
--  * Rejoin passed the job id as Teleport's `customLoadingScreen` argument, so
--    it always dropped you into a random server. It uses TeleportAsync with
--    ServerInstanceId now;
--  * "Teleport to Spawn" only searched the direct children of workspace.

local ctx = ...
local Util = ctx.require("core/Util")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")

local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMP_POWER = 50
local FAST_WALKSPEED = 240
local FAST_JUMP_POWER = 100
local FLY_SPEED_DEFAULT = 50
local RESPAWN_GRACE = 0.75

return function(hub, tab, cleanup)
	local state = {
		walkSpeed = DEFAULT_WALKSPEED,
		jumpPower = DEFAULT_JUMP_POWER,
		useJumpPower = false,
		flySpeed = FLY_SPEED_DEFAULT,
	}
	local reapply = {}

	local function humanoid(quiet)
		local hum = Util.getHumanoid()
		if not hum and not quiet then
			hub:notify("Character not ready", "error")
		end
		return hum
	end

	-- ---------------------------------------------------------------- walkspeed
	local walkSpeedEnabled = false
	tab:AddToggle("Walkspeed " .. FAST_WALKSPEED, false, function(on)
		walkSpeedEnabled = on
		local hum = humanoid()
		if not hum then
			return
		end
		if on then
			state.walkSpeed = hum.WalkSpeed
			hum.WalkSpeed = FAST_WALKSPEED
			hub:notify("Walkspeed set to " .. FAST_WALKSPEED, "success")
		else
			hum.WalkSpeed = state.walkSpeed
			hub:notify("Walkspeed restored to " .. state.walkSpeed, "info")
		end
	end)
	table.insert(reapply, function()
		if not walkSpeedEnabled then
			return
		end
		local hum = Util.getHumanoid()
		if hum then
			state.walkSpeed = DEFAULT_WALKSPEED
			hum.WalkSpeed = FAST_WALKSPEED
		end
	end)

	-- --------------------------------------------------------------- jump power
	local jumpPowerEnabled = false
	tab:AddToggle("Jump Power " .. FAST_JUMP_POWER, false, function(on)
		jumpPowerEnabled = on
		local hum = humanoid()
		if not hum then
			return
		end
		if on then
			state.jumpPower = hum.JumpPower
			state.useJumpPower = hum.UseJumpPower
			hum.UseJumpPower = true
			hum.JumpPower = FAST_JUMP_POWER
			hub:notify("Jump power set to " .. FAST_JUMP_POWER, "success")
		else
			hum.JumpPower = state.jumpPower
			hum.UseJumpPower = state.useJumpPower
			hub:notify("Jump power restored", "info")
		end
	end)
	table.insert(reapply, function()
		if not jumpPowerEnabled then
			return
		end
		local hum = Util.getHumanoid()
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = FAST_JUMP_POWER
		end
	end)

	-- -------------------------------------------------------------------- fly
	local fly = { active = false, bodyVelocity = nil, heartbeat = nil }

	local function stopFly(quiet)
		if fly.heartbeat then
			fly.heartbeat:Disconnect()
			fly.heartbeat = nil
		end
		if fly.bodyVelocity then
			fly.bodyVelocity:Destroy()
			fly.bodyVelocity = nil
		end

		local hum = Util.getHumanoid()
		if hum then
			hum.PlatformStand = false
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end

		fly.active = false
		if not quiet then
			hub:notify("Fly disabled", "info")
		end
	end
	cleanup.track(function()
		stopFly(true)
	end)

	local function flyDirection(camera)
		local direction = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			direction = direction + camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			direction = direction - camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			direction = direction - camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			direction = direction + camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			direction = direction + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			direction = direction - Vector3.new(0, 1, 0)
		end
		return direction
	end

	tab:AddToggle("Fly (WASD + Space/Shift)", false, function(on)
		if not on then
			stopFly()
			return
		end

		local hum = humanoid()
		local root = Util.getRootPart()
		if not hum or not root then
			return
		end

		hum.PlatformStand = true
		fly.active = true

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Name = "FrostFly"
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Velocity = Vector3.zero
		bodyVelocity.Parent = root
		fly.bodyVelocity = bodyVelocity

		fly.heartbeat = RunService.Heartbeat:Connect(function()
			if not fly.active then
				return
			end
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end

			-- The character can respawn mid-flight; keep the mover attached.
			local currentRoot = Util.getRootPart()
			if not currentRoot then
				return
			end
			if bodyVelocity.Parent ~= currentRoot then
				bodyVelocity.Parent = currentRoot
			end

			local direction = flyDirection(camera)
			if direction.Magnitude > 0.01 then
				bodyVelocity.Velocity = direction.Unit * state.flySpeed
			else
				bodyVelocity.Velocity = Vector3.zero
			end
		end)

		hub:notify("Fly enabled", "success")
	end)

	tab:AddSlider("Fly Speed", 10, 300, FLY_SPEED_DEFAULT, function(value)
		state.flySpeed = value
	end)

	-- ------------------------------------------------------------------ noclip
	local noclip = { connection = nil, saved = {} }

	local function stopNoclip(quiet)
		if noclip.connection then
			noclip.connection:Disconnect()
			noclip.connection = nil
		end
		for part, canCollide in pairs(noclip.saved) do
			if part.Parent then
				pcall(function()
					part.CanCollide = canCollide
				end)
			end
		end
		noclip.saved = {}
		if not quiet then
			hub:notify("NoClip disabled", "info")
		end
	end
	cleanup.track(function()
		stopNoclip(true)
	end)

	tab:AddToggle("NoClip", false, function(on)
		if not on then
			stopNoclip()
			return
		end

		noclip.connection = RunService.Stepped:Connect(function()
			local character = Util.getCharacter()
			if not character then
				return
			end
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					if noclip.saved[part] == nil then
						noclip.saved[part] = part.CanCollide
					end
					part.CanCollide = false
				end
			end
		end)
		hub:notify("NoClip enabled", "success")
	end)

	-- ------------------------------------------------------------- teleporting
	tab:AddButton("Teleport to Spawn", function()
		local root = Util.getRootPart()
		if not root then
			hub:notify("Character not ready", "error")
			return
		end

		-- Recursive: many games nest spawns inside a folder.
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if not spawn then
			hub:notify("No spawn location found", "error")
			return
		end

		root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
		hub:notify("Teleported to spawn", "success")
	end)

	tab:AddButton("Rejoin Server", function()
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = game.JobId

		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { Players.LocalPlayer }, options)
		end)

		if ok then
			hub:notify("Rejoining this server...", "info")
		else
			hub:notify("Rejoin failed: " .. tostring(err), "error")
		end
	end, true)

	tab:AddLabel("Universal features work in any game. Fly and NoClip persist until you turn them off or close the hub.", true)

	-- Re-apply enabled boosts when the character respawns or the hub is closed.
	cleanup.track(Players.LocalPlayer.CharacterAdded:Connect(function()
		Util.delay(RESPAWN_GRACE, function()
			for _, fn in ipairs(reapply) do
				pcall(fn)
			end
		end)
	end))

	return {
		stopFly = stopFly,
		stopNoclip = stopNoclip,
	}
end
