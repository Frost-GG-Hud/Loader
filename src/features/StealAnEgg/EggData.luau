-- Egg discovery, metadata reading, and spatial sorting.
-- Supports standard workspace models, __OBJECTS, AreaEggSlotsClient, and custom egg folders.

local ctx = ...
local Util = ctx.require("core/Util")

local CACHE_TTL = 0.4

local VALUE_ATTRIBUTES = {
	"Income",
	"Profit",
	"MoneyPerSecond",
	"IncomePerSecond",
	"CashPerSecond",
	"Value",
	"Price",
	"Worth",
	"RarityTier",
}
local VALUE_OBJECT_HINTS = { "income", "profit", "value", "worth", "cash", "rarity" }
local OWNER_ATTRIBUTES = { "Owner", "OwnerId", "OwnerName", "PlotOwner", "ClaimedBy", "Claimed" }

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 190, 205),
	Uncommon = Color3.fromRGB(85, 235, 120),
	Rare = Color3.fromRGB(60, 160, 255),
	Epic = Color3.fromRGB(185, 80, 255),
	Legendary = Color3.fromRGB(255, 185, 30),
	Mythic = Color3.fromRGB(255, 55, 100),
	Divine = Color3.fromRGB(0, 245, 220),
	Secret = Color3.fromRGB(255, 230, 80),
}

local EggData = {}
local cache = { instances = {}, stampedAt = -math.huge }

function EggData.nameMatches(instance)
	local lower = string.lower(instance.Name)
	return string.find(lower, "egg", 1, true) ~= nil
end

function EggData.isEgg(instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return false
	end
	if EggData.nameMatches(instance) then
		return true
	end
	if instance:FindFirstChild("EggType") ~= nil or instance:GetAttribute("EggType") ~= nil then
		return true
	end
	if instance:FindFirstChild("EggPoint", true) ~= nil then
		return true
	end
	if instance.Parent and instance.Parent.Name == "AreaEggSlotsClient" then
		return true
	end
	return false
end

function EggData.worldPositionOf(instance)
	if not instance or not instance.Parent then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	if instance:IsA("Model") then
		local eggPoint = instance:FindFirstChild("EggPoint", true)
		if eggPoint and eggPoint:IsA("BasePart") then
			return eggPoint.Position
		end
		if instance.PrimaryPart then
			return instance.PrimaryPart.Position
		end
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)
		if ok and pivot then
			return pivot.Position
		end
	end
	return nil
end

function EggData.valueOf(instance)
	for _, attributeName in ipairs(VALUE_ATTRIBUTES) do
		local value = instance:GetAttribute(attributeName)
		if type(value) == "number" then
			return value
		end
	end

	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("NumberValue") or child:IsA("IntValue") then
			local name = string.lower(child.Name)
			for _, hint in ipairs(VALUE_OBJECT_HINTS) do
				if string.find(name, hint, 1, true) then
					return child.Value
				end
			end
		end
	end
	return nil
end

function EggData.rarityOf(instance)
	local rarityAttr = instance:GetAttribute("Rarity") or instance:GetAttribute("RarityName") or instance:GetAttribute("Tier")
	if type(rarityAttr) == "string" and rarityAttr ~= "" then
		for rarityName, color in pairs(RARITY_COLORS) do
			if string.find(string.lower(rarityAttr), string.lower(rarityName), 1, true) then
				return rarityName, color
			end
		end
		return rarityAttr, Color3.fromRGB(255, 215, 0)
	end

	local val = EggData.valueOf(instance)
	if val then
		if val >= 1000000 then
			return "Divine", RARITY_COLORS.Divine
		elseif val >= 100000 then
			return "Mythic", RARITY_COLORS.Mythic
		elseif val >= 10000 then
			return "Legendary", RARITY_COLORS.Legendary
		elseif val >= 2500 then
			return "Epic", RARITY_COLORS.Epic
		elseif val >= 500 then
			return "Rare", RARITY_COLORS.Rare
		elseif val >= 100 then
			return "Uncommon", RARITY_COLORS.Uncommon
		end
	end

	return "Common", RARITY_COLORS.Common
end

function EggData.getPrompt(instance)
	local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	return prompt
end

function EggData.isClaimed(instance)
	local node = instance
	while node and node ~= workspace do
		for _, attributeName in ipairs(OWNER_ATTRIBUTES) do
			local value = node:GetAttribute(attributeName)
			if value ~= nil and value ~= "" and value ~= 0 and value ~= false then
				return true
			end
		end
		node = node.Parent
	end
	return false
end

function EggData.scan(force)
	local now = os.clock()
	if not force and #cache.instances > 0 and (now - cache.stampedAt) < CACHE_TTL then
		return cache.instances
	end

	local found = {}
	local seen = {}

	local function addIfEgg(inst)
		if inst and not seen[inst] and EggData.isEgg(inst) then
			seen[inst] = true
			table.insert(found, inst)
		end
	end

	-- Check dedicated client folder first (fastest)
	local clientFolder = workspace:FindFirstChild("AreaEggSlotsClient")
	if clientFolder then
		for _, child in ipairs(clientFolder:GetChildren()) do
			addIfEgg(child)
		end
	end

	-- Check __OBJECTS
	local objects = workspace:FindFirstChild("__OBJECTS")
	if objects then
		for _, desc in ipairs(objects:GetDescendants()) do
			addIfEgg(desc)
		end
	end

	-- Fallback scan of workspace
	for _, inst in ipairs(workspace:GetDescendants()) do
		addIfEgg(inst)
	end

	cache.instances = found
	cache.stampedAt = now
	return found
end

function EggData.invalidate()
	cache.instances = {}
	cache.stampedAt = -math.huge
end

function EggData.nearby(radius, force)
	local root = Util.getRootPart()
	if not root then
		return {}
	end

	local results = {}
	for _, instance in ipairs(EggData.scan(force)) do
		if instance.Parent then
			local position = EggData.worldPositionOf(instance)
			if position then
				local distance = (position - root.Position).Magnitude
				if radius == nil or distance <= radius then
					local rarityName, rarityColor = EggData.rarityOf(instance)
					table.insert(results, {
						instance = instance,
						position = position,
						distance = distance,
						value = EggData.valueOf(instance) or 0,
						rarity = rarityName,
						rarityColor = rarityColor,
						name = instance.Name,
					})
				end
			end
		end
	end

	table.sort(results, function(a, b)
		return a.distance < b.distance
	end)
	return results
end

function EggData.closest(radius)
	local nearby = EggData.nearby(radius)
	return nearby[1]
end

function EggData.bestValue()
	local best = nil
	for _, entry in ipairs(EggData.nearby(nil)) do
		if not EggData.isClaimed(entry.instance) then
			if not best or entry.value > best.value then
				best = entry
			end
		end
	end
	return best or EggData.closest()
end

function EggData.describe(instance)
	local attributes = instance:GetAttributes()
	local parts = {}
	for key, value in pairs(attributes) do
		table.insert(parts, key .. "=" .. tostring(value))
	end

	local children = {}
	for _, child in ipairs(instance:GetChildren()) do
		table.insert(children, child.ClassName .. ":" .. child.Name)
	end

	return table.concat(parts, ", "), table.concat(children, ", ")
end

return EggData
