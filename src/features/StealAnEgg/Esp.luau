-- Visuals: Egg ESP with rarity tags, Player ESP with info, and Trap ESP.

local ctx = ...
local Util = ctx.require("core/Util")
local EggData = ctx.require("features/StealAnEgg/EggData")

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

local TICK_INTERVAL = 0.5
local EGG_ESP_NAME = "_FrostEggESP"
local PLAYER_ESP_NAME = "_FrostPlayerESP"
local TRAP_ESP_NAME = "_FrostTrapESP"

local Esp = {}
Esp.__index = Esp

function Esp.new(config)
	local self = setmetatable({}, Esp)
	self.notify = config.notify or function() end
	self.range = config.range or 250
	self.eggsEnabled = false
	self.playersEnabled = false
	self.trapsEnabled = false
	self.running = false
	self.destroyed = false
	self.eggItems = {}
	self.playerItems = {}
	self.trapItems = {}
	return self
end

function Esp:_isActive()
	return self.eggsEnabled or self.playersEnabled or self.trapsEnabled
end

function Esp:_ensureLoop()
	if self.running or self.destroyed then
		return
	end
	self.running = true

	Util.spawn(function()
		while self:_isActive() and not self.destroyed do
			pcall(function()
				self:_tick()
			end)
			Util.wait(TICK_INTERVAL)
		end
		self.running = false
	end)
end

function Esp:_tick()
	if self.eggsEnabled then
		self:_tickEggs()
	else
		self:_clearEggEsp()
	end

	if self.playersEnabled then
		self:_tickPlayers()
	else
		self:_clearPlayerEsp()
	end

	if self.trapsEnabled then
		self:_tickTraps()
	else
		self:_clearTrapEsp()
	end
end

-- ----------------------------------------------------------------- Egg ESP
function Esp:_tickEggs()
	local activeSet = {}

	for _, entry in ipairs(EggData.nearby(self.range)) do
		local inst = entry.instance
		activeSet[inst] = true

		local existing = self.eggItems[inst]
		if existing and existing.billboard and existing.billboard.Parent then
			-- Update distance label
			existing.distLabel.Text = string.format("%.0f studs", entry.distance)
		else
			-- Create new highlight & billboard
			local highlight = Instance.new("Highlight")
			highlight.Name = EGG_ESP_NAME
			highlight.FillColor = entry.rarityColor
			highlight.FillTransparency = 0.5
			highlight.OutlineColor = entry.rarityColor
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = inst
			highlight.Parent = inst

			local billboard = Instance.new("BillboardGui")
			billboard.Name = EGG_ESP_NAME
			billboard.Size = UDim2.new(0, 140, 0, 36)
			billboard.StudsOffset = Vector3.new(0, 2.5, 0)
			billboard.AlwaysOnTop = true
			billboard.Adornee = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
			billboard.Parent = inst

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, 0, 0, 18)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 12
			nameLabel.TextColor3 = entry.rarityColor
			nameLabel.TextStrokeTransparency = 0.3
			nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			nameLabel.Text = string.format("[%s] %s", string.upper(entry.rarity), entry.name)
			nameLabel.Parent = billboard

			local distLabel = Instance.new("TextLabel")
			distLabel.Size = UDim2.new(1, 0, 0, 14)
			distLabel.Position = UDim2.fromOffset(0, 18)
			distLabel.BackgroundTransparency = 1
			distLabel.Font = Enum.Font.Gotham
			distLabel.TextSize = 10
			distLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
			distLabel.TextStrokeTransparency = 0.3
			distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			distLabel.Text = string.format("%.0f studs", entry.distance)
			distLabel.Parent = billboard

			self.eggItems[inst] = {
				highlight = highlight,
				billboard = billboard,
				distLabel = distLabel,
			}
		end
	end

	-- Clean up stale items
	for inst, item in pairs(self.eggItems) do
		if not activeSet[inst] or not inst.Parent then
			pcall(function()
				if item.highlight then item.highlight:Destroy() end
				if item.billboard then item.billboard:Destroy() end
			end)
			self.eggItems[inst] = nil
		end
	end
end

function Esp:_clearEggEsp()
	for inst, item in pairs(self.eggItems) do
		pcall(function()
			if item.highlight then item.highlight:Destroy() end
			if item.billboard then item.billboard:Destroy() end
		end)
	end
	self.eggItems = {}
end

-- --------------------------------------------------------------- Player ESP
function Esp:_tickPlayers()
	local root = Util.getRootPart()
	local myPos = root and root.Position or Vector3.zero

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local char = player.Character
			local pRoot = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")

			if pRoot and hum and hum.Health > 0 then
				local existing = self.playerItems[player]
				local dist = (pRoot.Position - myPos).Magnitude

				if existing and existing.billboard and existing.billboard.Parent then
					existing.infoLabel.Text = string.format("%.0f studs | HP: %d%%", dist, math.round((hum.Health / hum.MaxHealth) * 100))
				else
					if existing then
						pcall(function()
							if existing.box then existing.box:Destroy() end
							if existing.billboard then existing.billboard:Destroy() end
						end)
					end

					local color = player.TeamColor and player.TeamColor.Color or Color3.fromRGB(255, 75, 75)

					local box = Instance.new("BoxHandleAdornment")
					box.Name = PLAYER_ESP_NAME
					box.Size = pRoot.Size + Vector3.new(1.8, 2.5, 1.8)
					box.Color3 = color
					box.AlwaysOnTop = true
					box.Transparency = 0.55
					box.Adornee = pRoot
					box.Parent = pRoot

					local billboard = Instance.new("BillboardGui")
					billboard.Name = PLAYER_ESP_NAME
					billboard.Size = UDim2.new(0, 130, 0, 36)
					billboard.StudsOffset = Vector3.new(0, 3.5, 0)
					billboard.AlwaysOnTop = true
					billboard.Adornee = pRoot
					billboard.Parent = pRoot

					local nameLabel = Instance.new("TextLabel")
					nameLabel.Size = UDim2.new(1, 0, 0, 18)
					nameLabel.BackgroundTransparency = 1
					nameLabel.Font = Enum.Font.GothamBold
					nameLabel.TextSize = 12
					nameLabel.TextColor3 = color
					nameLabel.TextStrokeTransparency = 0.3
					nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
					nameLabel.Text = player.DisplayName
					nameLabel.Parent = billboard

					local infoLabel = Instance.new("TextLabel")
					infoLabel.Size = UDim2.new(1, 0, 0, 14)
					infoLabel.Position = UDim2.fromOffset(0, 18)
					infoLabel.BackgroundTransparency = 1
					infoLabel.Font = Enum.Font.Gotham
					infoLabel.TextSize = 10
					infoLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
					infoLabel.TextStrokeTransparency = 0.3
					infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
					infoLabel.Text = string.format("%.0f studs | HP: %d%%", dist, math.round((hum.Health / hum.MaxHealth) * 100))
					infoLabel.Parent = billboard

					self.playerItems[player] = {
						box = box,
						billboard = billboard,
						infoLabel = infoLabel,
					}
				end
			end
		end
	end

	for player, item in pairs(self.playerItems) do
		local char = player.Character
		local pRoot = char and char:FindFirstChild("HumanoidRootPart")
		if not player.Parent or not char or not pRoot or not pRoot.Parent then
			pcall(function()
				if item.box then item.box:Destroy() end
				if item.billboard then item.billboard:Destroy() end
			end)
			self.playerItems[player] = nil
		end
	end
end

function Esp:_clearPlayerEsp()
	for player, item in pairs(self.playerItems) do
		pcall(function()
			if item.box then item.box:Destroy() end
			if item.billboard then item.billboard:Destroy() end
		end)
	end
	self.playerItems = {}
end

-- ----------------------------------------------------------------- Trap ESP
function Esp:_tickTraps()
	local activeTraps = {}
	local trapList = CollectionService:GetTagged("PlacedTrap")

	for _, trap in ipairs(trapList) do
		if trap and trap.Parent then
			activeTraps[trap] = true
			if not self.trapItems[trap] then
				local part = trap:IsA("BasePart") and trap or trap:FindFirstChildWhichIsA("BasePart", true)
				if part then
					local highlight = Instance.new("Highlight")
					highlight.Name = TRAP_ESP_NAME
					highlight.FillColor = Color3.fromRGB(255, 60, 60)
					highlight.FillTransparency = 0.4
					highlight.OutlineColor = Color3.fromRGB(255, 120, 120)
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Adornee = trap
					highlight.Parent = trap

					local billboard = Instance.new("BillboardGui")
					billboard.Name = TRAP_ESP_NAME
					billboard.Size = UDim2.new(0, 90, 0, 20)
					billboard.StudsOffset = Vector3.new(0, 2, 0)
					billboard.AlwaysOnTop = true
					billboard.Adornee = part
					billboard.Parent = trap

					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(1, 0, 1, 0)
					label.BackgroundTransparency = 1
					label.Font = Enum.Font.GothamBold
					label.TextSize = 11
					label.TextColor3 = Color3.fromRGB(255, 80, 80)
					label.TextStrokeTransparency = 0.3
					label.Text = "⚠️ TRAP"
					label.Parent = billboard

					self.trapItems[trap] = { highlight = highlight, billboard = billboard }
				end
			end
		end
	end

	for trap, item in pairs(self.trapItems) do
		if not activeTraps[trap] or not trap.Parent then
			pcall(function()
				if item.highlight then item.highlight:Destroy() end
				if item.billboard then item.billboard:Destroy() end
			end)
			self.trapItems[trap] = nil
		end
	end
end

function Esp:_clearTrapEsp()
	for trap, item in pairs(self.trapItems) do
		pcall(function()
			if item.highlight then item.highlight:Destroy() end
			if item.billboard then item.billboard:Destroy() end
		end)
	end
	self.trapItems = {}
end

function Esp:setEggs(enabled)
	self.eggsEnabled = enabled == true
	if self.eggsEnabled then
		self:_ensureLoop()
		self.notify("Egg ESP enabled", "success")
	else
		self:_clearEggEsp()
		self.notify("Egg ESP disabled", "info")
	end
end

function Esp:setPlayers(enabled)
	self.playersEnabled = enabled == true
	if self.playersEnabled then
		self:_ensureLoop()
		self.notify("Player ESP enabled", "success")
	else
		self:_clearPlayerEsp()
		self.notify("Player ESP disabled", "info")
	end
end

function Esp:setTraps(enabled)
	self.trapsEnabled = enabled == true
	if self.trapsEnabled then
		self:_ensureLoop()
		self.notify("Trap ESP enabled", "success")
	else
		self:_clearTrapEsp()
		self.notify("Trap ESP disabled", "info")
	end
end

function Esp:setRange(value)
	self.range = math.max(10, tonumber(value) or self.range)
end

function Esp:clear()
	self:_clearEggEsp()
	self:_clearPlayerEsp()
	self:_clearTrapEsp()
end

function Esp:destroy()
	self.destroyed = true
	self.eggsEnabled = false
	self.playersEnabled = false
	self.trapsEnabled = false
	self:clear()
end

return Esp
