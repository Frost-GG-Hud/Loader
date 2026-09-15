-- Egg discovery, metadata reading, Pet name resolution, and Money/sec extraction.

local ctx = ...
local Util = ctx.require("core/Util")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local CACHE_TTL = 0.35

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
local assetDirectory = nil

-- Attempt to load Assets directory from ReplicatedStorage
pcall(function()
	local assetsModule = ReplicatedStorage:FindFirstChild("Data") and ReplicatedStorage.Data:FindFirstChild("Assets")
	if assetsModule and assetsModule:IsA("ModuleScript") then
		local loaded = require(assetsModule)
		if type(loaded) == "table" then
			assetDirectory = loaded.Directory or loaded
		end
	end
end)

function EggData.formatMoney(amount)
	if not amount or type(amount) ~= "number" or amount <= 0 then
		return "+$0/s"
	end
	if amount >= 1e9 then
		return string.format("+$%.1fB/s", amount / 1e9)
	elseif amount >= 1e6 then
		return string.format("+$%.1fM/s", amount / 1e6)
	elseif amount >= 1e3 then
		return string.format("+$%.1fK/s", amount / 1e3)
	else
		return string.format("+$%.0f/s", amount)
	end
end

function EggData.isEgg(instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return false
	end
	if instance.Parent and instance.Parent.Name == "AreaEggSlotsClient" then
		return true
	end
	local lower = string.lower(instance.Name)
	if string.find(lower, "egg", 1, true) ~= nil then
		return true
	end
	if instance:FindFirstChild("EggType") ~= nil or instance:GetAttribute("EggType") ~= nil then
		return true
	end
	if instance:FindFirstChild("EggPoint", true) ~= nil then
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

-- Extracts the Pet Name that will hatch and the Money Per Second
function EggData.getPetInfo(instance)
	local petName = nil
	local moneyPerSec = 0
	local rarity = "Common"

	-- 1. Try category key from attributes or children
	local category = instance:GetAttribute("AssetCategory")
		or instance:GetAttribute("Category")
		or instance:GetAttribute("EggType")
		or instance:GetAttribute("PetName")

	if not category then
		local catVal = instance:FindFirstChild("Category") or instance:FindFirstChild("EggType") or instance:FindFirstChild("PetName")
		if catVal and catVal:IsA("StringValue") then
			category = catVal.Value
		end
	end

	-- 2. Lookup in Assets directory if available
	if category and assetDirectory and assetDirectory[category] then
		local entry = assetDirectory[category]
		if entry.Egg and entry.Egg.DisplayName then
			petName = entry.Egg.DisplayName
		elseif entry.DisplayName then
			petName = entry.DisplayName
		end

		if entry.Rarity then
			rarity = entry.Rarity.DisplayName or entry.Rarity._id or rarity
			if type(entry.Rarity.DefaultRarityValue) == "number" then
				moneyPerSec = entry.Rarity.DefaultRarityValue
			end
		end

		if type(entry.Income) == "number" then
			moneyPerSec = entry.Income
		end
	end

	-- 3. Read money from attributes
	local moneyAttr = instance:GetAttribute("Income")
		or instance:GetAttribute("MoneyPerSecond")
		or instance:GetAttribute("CashPerSecond")
		or instance:GetAttribute("IncomePerSecond")
		or instance:GetAttribute("Profit")
		or instance:GetAttribute("Value")

	if type(moneyAttr) == "number" and moneyAttr > 0 then
		moneyPerSec = moneyAttr
	end

	-- 4. Read pet name fallback from attributes or clean name
	if not petName then
		local nameAttr = instance:GetAttribute("DisplayName") or instance:GetAttribute("PetName") or instance:GetAttribute("Name")
		if type(nameAttr) == "string" and nameAttr ~= "" and not string.find(nameAttr, "Slot", 1, true) then
			petName = nameAttr
		end
	end

	-- Clean up if still nil or contains slot numbers like "AreaEggSlot_42"
	if not petName or string.find(petName, "Slot", 1, true) or string.find(petName, "^%d+$") then
		local rawName = instance.Name
		-- Strip slot prefixes and numbers
		local clean = string.gsub(rawName, "AreaEggSlot_", "")
		clean = string.gsub(clean, "[_%d]+$", "")
		clean = string.gsub(clean, "^_+", "")
		if clean ~= "" and clean ~= "Egg" then
			petName = clean
		else
			petName = "Mystery Egg"
		end
	end

	-- 5. Resolve rarity & color
	local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	if moneyPerSec >= 1000000 then
		rarity = "Divine"
		rarityColor = RARITY_COLORS.Divine
	elseif moneyPerSec >= 100000 then
		rarity = "Mythic"
		rarityColor = RARITY_COLORS.Mythic
	elseif moneyPerSec >= 10000 then
		rarity = "Legendary"
		rarityColor = RARITY_COLORS.Legendary
	elseif moneyPerSec >= 2500 then
		rarity = "Epic"
		rarityColor = RARITY_COLORS.Epic
	elseif moneyPerSec >= 500 then
		rarity = "Rare"
		rarityColor = RARITY_COLORS.Rare
	elseif moneyPerSec >= 100 then
		rarity = "Uncommon"
		rarityColor = RARITY_COLORS.Uncommon
	end

	return petName, moneyPerSec, rarity, rarityColor
end

function EggData.getPrompt(instance)
	return instance:FindFirstChildWhichIsA("ProximityPrompt", true)
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

	local clientFolder = workspace:FindFirstChild("AreaEggSlotsClient")
	if clientFolder then
		for _, child in ipairs(clientFolder:GetChildren()) do
			addIfEgg(child)
		end
	end

	local objects = workspace:FindFirstChild("__OBJECTS")
	if objects then
		for _, desc in ipairs(objects:GetDescendants()) do
			addIfEgg(desc)
		end
	end

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
					local petName, moneyPerSec, rarity, rarityColor = EggData.getPetInfo(instance)
					table.insert(results, {
						instance = instance,
						position = position,
						distance = distance,
						petName = petName,
						moneyPerSec = moneyPerSec,
						moneyText = EggData.formatMoney(moneyPerSec),
						rarity = rarity,
						rarityColor = rarityColor,
						name = petName,
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

-- Best egg: highest money per second and rarity
function EggData.bestValue()
	local all = EggData.nearby(nil)
	if #all == 0 then
		return nil
	end

	table.sort(all, function(a, b)
		if a.moneyPerSec ~= b.moneyPerSec then
			return a.moneyPerSec > b.moneyPerSec
		end
		return a.distance < b.distance
	end)

	return all[1]
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
