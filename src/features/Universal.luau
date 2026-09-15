-- Universal features: movement hacks, flight, lighting, graphics optimization, server utils.

local ctx = ...
local Util = ctx.require("core/Util")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")

local DEFAULT_WALKSPEED = 16
local DEFAULT_JUMP_POWER = 50
local FLY_SPEED_DEFAULT = 60
local RESPAWN_GRACE = 0.75

return function(hub, tab, cleanup)
	local state = {
		walkSpeed = DEFAULT_WALKSPEED,
		targetWalkSpeed = 100,
		jumpPower = DEFAULT_JUMP_POWER,
		targetJumpPower = 100,
		useJumpPower = false,
		flySpeed = FLY_SPEED_DEFAULT,
		fullbrightEnabled = false,
		infJumpEnabled = false,
	}
	local reapply = {}

	local function humanoid(quiet)
		local hum = Util.getHumanoid()
		if not hum and not quiet then
			hub:notify("Character not ready", "error")
		end
		return hum
	end

	-- ------------------------------------------------------------- MOVEMENT
	tab:AddSection("Movement & Physics")

	local walkSpeedEnabled = false
	tab:AddToggle("Custom Walkspeed", false, function(on)
		walkSpeedEnabled = on
		local hum = humanoid()
		if not hum then
			return
		end
		if on then
			state.walkSpeed = hum.WalkSpeed
			hum.WalkSpeed = state.targetWalkSpeed
			hub:notify("Walkspeed set to " .. state.targetWalkSpeed, "success")
		else
			hum.WalkSpeed = state.walkSpeed
			hub:notify("Walkspeed restored", "info")
		end
	end)

	tab:AddSlider("Walkspeed Multiplier", 16, 300, 100, function(value)
		state.targetWalkSpeed = value
		if walkSpeedEnabled then
			local hum = humanoid(true)
			if hum then
				hum.WalkSpeed = value
			end
		end
	end)

	table.insert(reapply, function()
		if not walkSpeedEnabled then
			return
		end
		local hum = Util.getHumanoid()
		if hum then
			hum.WalkSpeed = state.targetWalkSpeed
		end
	end)

	local jumpPowerEnabled = false
	tab:AddToggle("Custom Jump Power", false, function(on)
		jumpPowerEnabled = on
		local hum = humanoid()
		if not hum then
			return
		end
		if on then
			state.jumpPower = hum.JumpPower
			state.useJumpPower = hum.UseJumpPower
			hum.UseJumpPower = true
			hum.JumpPower = state.targetJumpPower
			hub:notify("Jump power set to " .. state.targetJumpPower, "success")
		else
			hum.JumpPower = state.jumpPower
			hum.UseJumpPower = state.useJumpPower
			hub:notify("Jump power restored", "info")
		end
	end)

	tab:AddSlider("Jump Power Multiplier", 50, 350, 100, function(value)
		state.targetJumpPower = value
		if jumpPowerEnabled then
			local hum = humanoid(true)
			if hum then
				hum.UseJumpPower = true
				hum.JumpPower = value
			end
		end
	end)

	table.insert(reapply, function()
		if not jumpPowerEnabled then
			return
		end
		local hum = Util.getHumanoid()
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = state.targetJumpPower
		end
	end)

	-- Infinite Jump
	local infJumpConn = nil
	tab:AddToggle("Infinite Jump (Space in air)", false, function(on)
		state.infJumpEnabled = on
		if on then
			if not infJumpConn then
				infJumpConn = UserInputService.JumpRequest:Connect(function()
					if state.infJumpEnabled then
						local hum = humanoid(true)
						if hum then
							hum:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end)
			end
			hub:notify("Infinite Jump enabled", "success")
		else
			hub:notify("Infinite Jump disabled", "info")
		end
	end)
	cleanup.track(function()
		if infJumpConn then
			infJumpConn:Disconnect()
			infJumpConn = nil
		end
	end)

	-- -------------------------------------------------------------------- FLY
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

	-- ---------------------------------------------------------------- NOCLIP
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

	tab:AddToggle("NoClip (Walk Through Walls)", false, function(on)
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

	-- ------------------------------------------------------------- LIGHTING
	tab:AddSection("Visuals & Lighting")

	local originalBrightness = Lighting.Brightness
	local originalShadows = Lighting.GlobalShadows
	local originalFog = Lighting.FogEnd

	tab:AddToggle("Fullbright (See In Dark)", false, function(on)
		state.fullbrightEnabled = on
		pcall(function()
			if on then
				Lighting.Brightness = 2
				Lighting.GlobalShadows = false
				Lighting.FogEnd = 9e9
				hub:notify("Fullbright enabled", "success")
			else
				Lighting.Brightness = originalBrightness
				Lighting.GlobalShadows = originalShadows
				Lighting.FogEnd = originalFog
				hub:notify("Fullbright restored", "info")
			end
		end)
	end)

	-- --------------------------------------------------------- PERFORMANCE
	tab:AddSection("Performance & Optimization")

	tab:AddButton("Boost FPS / Low Graphics Mode", function()
		pcall(function()
			for _, v in ipairs(workspace:GetDescendants()) do
				if v:IsA("BasePart") then
					v.Material = Enum.Material.SmoothPlastic
					v.Reflectance = 0
				elseif v:IsA("Decal") or v:IsA("Texture") then
					v.Transparency = 1
				elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
					v.Enabled = false
				end
			end
			Lighting.GlobalShadows = false
			for _, v in ipairs(Lighting:GetChildren()) do
				if v:IsA("PostEffect") then
					v.Enabled = false
				end
			end
			hub:notify("Low graphics applied! FPS boosted.", "success")
		end)
	end)

	-- ------------------------------------------------------------- UTILITIES
	tab:AddSection("Server Utilities")

	tab:AddButton("Teleport to Spawn", function()
		local root = Util.getRootPart()
		if not root then
			hub:notify("Character not ready", "error")
			return
		end

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
			hub:notify("Rejoining server...", "info")
		else
			hub:notify("Rejoin failed: " .. tostring(err), "error")
		end
	end, true)

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
