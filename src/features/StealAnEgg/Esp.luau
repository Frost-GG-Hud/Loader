-- Egg and player ESP.
--
-- Bugs fixed from the original:
--  * Player ESP threw on every tick: `BoxHandleAdornment` exposes `Color3`, not
--    `Color` (that is a deprecated, hidden GuiBase3d property), so the loop died
--    immediately and no boxes ever appeared;
--  * toggling on/off/on quickly spawned duplicate loops. A single shared loop
--    now drives both highlight types;
--  * highlights were never removed when an egg left range, leaving stale ESP all
--    over the map. Tracked highlights are pruned each tick;
--  * the "ESP Draw Distance" slider was wired to an empty function. It now
--    actually bounds which eggs are highlighted.

local ctx = ...
local Util = ctx.require("core/Util")
local EggData = ctx.require("features/StealAnEgg/EggData")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local TICK_INTERVAL = 0.65
local EGG_HIGHLIGHT_NAME = "_FrostEggESP"
local PLAYER_ADORNMENT_NAME = "_FrostPlayerESP"
local PREDICTION_NAME = "_FrostPredict"
local PREDICTION_LIFETIME = 5
local PREDICTION_MARKER_OFFSET = 2

local EGG_FILL = Color3.fromRGB(255, 204, 0)
local EGG_OUTLINE = Color3.fromRGB(255, 238, 150)
local PLAYER_FALLBACK_COLOR = Color3.fromRGB(235, 94, 94)

local Esp = {}
Esp.__index = Esp

function Esp.new(config)
	local self = setmetatable({}, Esp)
	self.notify = config.notify
	self.range = config.range or 150
	self.eggsEnabled = false
	self.playersEnabled = false
	self.running = false
	self.destroyed = false
	self.eggHighlights = {}
	self.playerBoxes = {}
	return self
end

function Esp:_isActive()
	return self.eggsEnabled or self.playersEnabled
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
		self:_clearEggHighlights()
	end

	if self.playersEnabled then
		self:_tickPlayers()
	else
		self:_clearPlayerBoxes()
	end
end

function Esp:_tickEggs()
	local inRange = {}
	for _, entry in ipairs(EggData.nearby(self.range)) do
		inRange[entry.instance] = true

		if not entry.instance:FindFirstChild(EGG_HIGHLIGHT_NAME) then
			local highlight = Instance.new("Highlight")
			highlight.Name = EGG_HIGHLIGHT_NAME
			highlight.FillColor = EGG_FILL
			highlight.FillTransparency = 0.55
			highlight.OutlineColor = EGG_OUTLINE
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = entry.instance
			highlight.Parent = entry.instance
			table.insert(self.eggHighlights, {
				instance = entry.instance,
				highlight = highlight,
			})
		end
	end

	-- Prune anything that died, left range, or was removed by the game.
	local kept = {}
	for _, tracked in ipairs(self.eggHighlights) do
		local alive = tracked.instance.Parent ~= nil and tracked.highlight.Parent ~= nil
		if alive and inRange[tracked.instance] then
			table.insert(kept, tracked)
		else
			pcall(function()
				tracked.highlight:Destroy()
			end)
		end
	end
	self.eggHighlights = kept
end

function Esp:_clearEggHighlights()
	for _, tracked in ipairs(self.eggHighlights) do
		pcall(function()
			tracked.highlight:Destroy()
		end)
	end
	self.eggHighlights = {}
end

function Esp:_tickPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local existing = self.playerBoxes[player]
				if existing and existing.Parent == root then
					-- Already tracking this character.
				else
					if existing then
						pcall(function()
							existing:Destroy()
						end)
					end

					local color = PLAYER_FALLBACK_COLOR
					if player.TeamColor then
						color = player.TeamColor.Color
					end

					local box = Instance.new("BoxHandleAdornment")
					box.Name = PLAYER_ADORNMENT_NAME
					box.Size = root.Size + Vector3.new(1.6, 1.6, 1.6)
					box.Color3 = color
					box.AlwaysOnTop = true
					box.Transparency = 0.55
					box.Adornee = root
					box.Parent = root
					self.playerBoxes[player] = box
				end
			end
		end
	end

	for player, box in pairs(self.playerBoxes) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not box.Parent or not root or box.Parent ~= root then
			pcall(function()
				box:Destroy()
			end)
			self.playerBoxes[player] = nil
		end
	end
end

function Esp:_clearPlayerBoxes()
	for player, box in pairs(self.playerBoxes) do
		pcall(function()
			box:Destroy()
		end)
		self.playerBoxes[player] = nil
	end
end

function Esp:setEggs(enabled)
	enabled = enabled == true
	if self.eggsEnabled == enabled then
		return
	end
	self.eggsEnabled = enabled

	if enabled then
		self:_ensureLoop()
		self.notify("Egg ESP enabled (range " .. self.range .. ")", "success")
	else
		self:_clearEggHighlights()
		self.notify("Egg ESP disabled", "info")
	end
end

function Esp:setPlayers(enabled)
	enabled = enabled == true
	if self.playersEnabled == enabled then
		return
	end
	self.playersEnabled = enabled

	if enabled then
		self:_ensureLoop()
		self.notify("Player ESP enabled", "success")
	else
		self:_clearPlayerBoxes()
		self.notify("Player ESP disabled", "info")
	end
end

function Esp:setRange(value)
	self.range = math.max(10, tonumber(value) or self.range)
end

-- Temporary billboard markers, useful for spotting an egg before committing.
function Esp:predict()
	local nearby = EggData.nearby(self.range)
	local marked = 0

	for _, entry in ipairs(nearby) do
		local position = entry.position
		if position then
			marked = marked + 1

			local marker = Instance.new("Part")
			marker.Name = PREDICTION_NAME
			marker.Anchored = true
			marker.CanCollide = false
			marker.CanQuery = false
			marker.CanTouch = false
			marker.Transparency = 1
			marker.Size = Vector3.new(1, 1, 1)
			marker.CFrame = CFrame.new(position + Vector3.new(0, PREDICTION_MARKER_OFFSET, 0))
			marker.Parent = workspace

			local billboard = Instance.new("BillboardGui")
			billboard.Name = PREDICTION_NAME
			billboard.Size = UDim2.new(0, 96, 0, 22)
			billboard.StudsOffset = Vector3.new(0, 2, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = marker

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 0.4
			label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			label.TextColor3 = EGG_FILL
			label.Font = Enum.Font.GothamBold
			label.TextSize = 12
			label.Text = string.format("Egg  %.0f studs", entry.distance)
			label.Parent = billboard

			Util.delay(PREDICTION_LIFETIME, function()
				if marker.Parent then
					marker:Destroy()
				end
			end)
		end
	end

	return marked
end

function Esp:countHighlights()
	return #self.eggHighlights, next(self.playerBoxes) ~= nil
end

function Esp:clear()
	self:_clearEggHighlights()
	self:_clearPlayerBoxes()

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == PREDICTION_NAME then
			if descendant:IsA("Part") or descendant:IsA("BillboardGui") then
				pcall(function()
					descendant:Destroy()
				end)
			end
		end
	end
end

function Esp:destroy()
	self.destroyed = true
	self.eggsEnabled = false
	self.playersEnabled = false
	self:clear()
end

return Esp
