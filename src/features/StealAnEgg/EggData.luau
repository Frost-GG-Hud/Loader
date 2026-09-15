-- Egg discovery, metadata reading, Pet & Egg name resolution, and Pet Money/sec extraction.
-- Directly extracts the Pet's Hatch Name and true Money/Sec from ReplicatedStorage AssetEarnings.

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

local TIER_BASE_MONEY = {
	Common = 50,
	Uncommon = 150,
	Rare = 500,
	Epic = 2500,
	Legendary = 15000,
	Mythic = 100000,
	Divine = 750000,
	Secret = 5000000,
}

local EggData = {}
local cache = { entries = {}, stampedAt = -math.huge }
local assetDirectory = nil
local eggStateModule = nil
local assetEarningsModule = nil
local areaEggSlotIdentity = nil

-- Attempt to require game data modules
pcall(function()
	local assetsMod = ReplicatedStorage:FindFirstChild("Data") and ReplicatedStorage.Data:FindFirstChild("Assets")
	if assetsMod and assetsMod:IsA("ModuleScript") then
		local loaded = require(assetsMod)
		if type(loaded) == "table" then
			assetDirectory = loaded.Directory or loaded
		end
	end
end)

pcall(function()
	local earnMod = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Util")
		and ReplicatedStorage.Shared.Util:FindFirstChild("AssetEarnings")
	if earnMod and earnMod:IsA("ModuleScript") then
		assetEarningsModule = require(earnMod)
	end
end)

pcall(function()
	local eggStateMod = ReplicatedStorage:FindFirstChild("Client") and ReplicatedStorage.Client:FindFirstChild("EggState")
	if eggStateMod and eggStateMod:IsA("ModuleScript") then
		eggStateModule = require(eggStateMod)
	end
end)

pcall(function()
	local identMod = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Util")
		and ReplicatedStorage.Shared.Util:FindFirstChild("AreaEggSlotIdentity")
	if identMod and identMod:IsA("ModuleScript") then
		areaEggSlotIdentity = require(identMod)
	end
end)

function EggData.formatMoney(amount)
	if not amount or type(amount) ~= "number" or amount <= 0 then
		return "+$50/s"
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

-- Checks if a string looks like a 32-character hexadecimal UID
local function isHexUid(str)
	if type(str) ~= "string" or #str ~= 32 then
		return false
	end
	return string.match(str, "^[0-9a-fA-F]+$") ~= nil
end

-- Blacklist check for non-egg parts
function EggData.isIgnoredPart(name)
	local lower = string.lower(tostring(name))
	if string.find(lower, "bounds", 1, true)
		or string.find(lower, "fit", 1, true)
		or string.find(lower, "machine", 1, true)
		or string.find(lower, "fuse", 1, true)
		or string.find(lower, "stand", 1, true)
		or string.find(lower, "shop", 1, true)
		or string.find(lower, "nest", 1, true)
		or string.find(lower, "base", 1, true)
		or string.find(lower, "platform", 1, true)
		or string.find(lower, "cube", 1, true)
		or string.find(lower, "mesh", 1, true)
	then
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

-- Resolves the clean Egg Name, Pet Name, and true Money Per Second of the hatching pet
function EggData.resolveEggMetadata(category, uid, instance)
	local petName = "Chicken"
	local eggName = "Normal Egg"
	local rarity = "Common"
	local moneyPerSec = 0

	-- 1. Try Assets Directory lookup
	if category and assetDirectory and assetDirectory[category] then
		local entry = assetDirectory[category]
		if entry.DisplayName then
			petName = entry.DisplayName
		end
		if entry.Egg and entry.Egg.DisplayName then
			eggName = entry.Egg.DisplayName
		end
		if entry.Rarity then
			rarity = entry.Rarity.DisplayName or entry.Rarity._id or "Common"
			if type(entry.Rarity.DefaultRarityValue) == "number" and entry.Rarity.DefaultRarityValue > 0 then
				moneyPerSec = entry.Rarity.DefaultRarityValue
			end
		end

		-- Compute true pet rate per second via AssetEarnings
		if assetEarningsModule and assetEarningsModule.RatePerSecond then
			pcall(function()
				local rate = assetEarningsModule.RatePerSecond({
					Category = category,
					Scale = 1,
					Personality = "Normal",
					Mutations = {},
				})
				if type(rate) == "number" and rate > 0 then
					moneyPerSec = rate
				end
			end)
		end

		if moneyPerSec <= 0 and type(entry.Income) == "number" and entry.Income > 0 then
			moneyPerSec = entry.Income
		end
	elseif category and type(category) == "string" and not isHexUid(category) then
		petName = category
		eggName = category .. " Egg"
	end

	-- 2. Read from instance attributes
	if instance then
		local attrPet = instance:GetAttribute("PetName") or instance:GetAttribute("Pet") or instance:GetAttribute("DisplayName")
		if type(attrPet) == "string" and attrPet ~= "" and not isHexUid(attrPet) and not EggData.isIgnoredPart(attrPet) then
			petName = attrPet
		end

		local attrEgg = instance:GetAttribute("EggName") or instance:GetAttribute("EggType")
		if type(attrEgg) == "string" and attrEgg ~= "" and not isHexUid(attrEgg) and not EggData.isIgnoredPart(attrEgg) then
			eggName = attrEgg
		end

		local attrMoney = instance:GetAttribute("Income")
			or instance:GetAttribute("MoneyPerSecond")
			or instance:GetAttribute("CashPerSecond")
			or instance:GetAttribute("Profit")
		if type(attrMoney) == "number" and attrMoney > 0 then
			moneyPerSec = attrMoney
		end

		local attrRarity = instance:GetAttribute("Rarity") or instance:GetAttribute("RarityName")
		if type(attrRarity) == "string" and attrRarity ~= "" then
			rarity = attrRarity
		end
	end

	-- Guaranteed non-zero money per second calculation based on rarity
	if moneyPerSec <= 0 then
		moneyPerSec = TIER_BASE_MONEY[rarity] or 50
	end

	local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	-- Clean format requested: (Egg Name) Pet Name -> e.g. (Normal Egg) Chicken
	local cleanDisplay = string.format("(%s) %s", eggName, petName)

	return {
		petName = petName,
		eggName = eggName,
		cleanDisplay = cleanDisplay,
		rarity = rarity,
		rarityColor = rarityColor,
		moneyPerSec = moneyPerSec,
		moneyText = EggData.formatMoney(moneyPerSec),
	}
end

function EggData.getPrompt(instance)
	if not instance then return nil end
	local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and prompt.ActionText == "Steal" then
		return prompt
	end
	if prompt then return prompt end

	if instance.Parent and instance.Parent ~= workspace then
		prompt = instance.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
	end
	return prompt
end

function EggData.scan(force)
	local now = os.clock()
	if not force and #cache.entries > 0 and (now - cache.stampedAt) < CACHE_TTL then
		return cache.entries
	end

	local results = {}
	local seenUids = {}
	local seenInstances = {}

	-- Method 1: Query EggState.ReadFieldEggs() (The official game state)
	if eggStateModule and eggStateModule.ReadFieldEggs then
		pcall(function()
			local snapshot = eggStateModule.ReadFieldEggs()
			if snapshot and type(snapshot.Records) == "table" then
				for _, record in ipairs(snapshot.Records) do
					local uid = record.Uid
					if uid and not seenUids[uid] then
						seenUids[uid] = true

						local model = workspace:FindFirstChild(uid)
						if not model then
							local clientFolder = workspace:FindFirstChild("AreaEggSlotsClient")
							if clientFolder then
								model = clientFolder:FindFirstChild(uid)
							end
						end

						local worldPos = nil
						if model then
							worldPos = EggData.worldPositionOf(model)
						elseif record.BoundsCFrame then
							worldPos = record.BoundsCFrame.Position
						end

						if worldPos then
							if model then
								seenInstances[model] = true
							end

							local meta = EggData.resolveEggMetadata(record.AssetCategory, uid, model)
							local prompt = model and EggData.getPrompt(model) or nil
							local slotKey = nil
							if areaEggSlotIdentity and areaEggSlotIdentity.LooksLikeFirstAreaUid(uid) then
								slotKey = areaEggSlotIdentity.SlotKey(record.AreaId, record.NestId)
							end

							table.insert(results, {
								uid = uid,
								slotKey = slotKey,
								instance = model or record,
								model = model,
								position = worldPos,
								petName = meta.petName,
								eggName = meta.eggName,
								cleanDisplay = meta.cleanDisplay,
								rarity = meta.rarity,
								rarityColor = meta.rarityColor,
								moneyPerSec = meta.moneyPerSec,
								moneyText = meta.moneyText,
								prompt = prompt,
								record = record,
							})
						end
					end
				end
			end
		end)
	end

	-- Method 2: Scan AreaEggSlotsClient directly
	local clientFolder = workspace:FindFirstChild("AreaEggSlotsClient")
	if clientFolder then
		for _, child in ipairs(clientFolder:GetChildren()) do
			if child:IsA("Model") and not seenInstances[child] and not seenUids[child.Name] and not EggData.isIgnoredPart(child.Name) then
				seenInstances[child] = true
				seenUids[child.Name] = true

				local worldPos = EggData.worldPositionOf(child)
				if worldPos then
					local category = child:GetAttribute("AssetCategory") or child:GetAttribute("Category")
					local meta = EggData.resolveEggMetadata(category, child.Name, child)
					local prompt = EggData.getPrompt(child)

					table.insert(results, {
						uid = child.Name,
						instance = child,
						model = child,
						position = worldPos,
						petName = meta.petName,
						eggName = meta.eggName,
						cleanDisplay = meta.cleanDisplay,
						rarity = meta.rarity,
						rarityColor = meta.rarityColor,
						moneyPerSec = meta.moneyPerSec,
						moneyText = meta.moneyText,
						prompt = prompt,
					})
				end
			end
		end
	end

	-- Method 3: Fallback scan for ProximityPrompts with ActionText == "Steal"
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and (desc.Name == "CarryAreaEgg" or desc.ActionText == "Steal") then
			local model = desc.Parent
			while model and model ~= workspace and not model:IsA("Model") do
				model = model.Parent
			end

			if model and model ~= workspace and not seenInstances[model] and not EggData.isIgnoredPart(model.Name) then
				seenInstances[model] = true
				local worldPos = EggData.worldPositionOf(model) or (desc.Parent:IsA("BasePart") and desc.Parent.Position)
				if worldPos then
					local meta = EggData.resolveEggMetadata(nil, model.Name, model)
					table.insert(results, {
						uid = model.Name,
						instance = model,
						model = model,
						position = worldPos,
						petName = meta.petName,
						eggName = meta.eggName,
						cleanDisplay = meta.cleanDisplay,
						rarity = meta.rarity,
						rarityColor = meta.rarityColor,
						moneyPerSec = meta.moneyPerSec,
						moneyText = meta.moneyText,
						prompt = desc,
					})
				end
			end
		end
	end

	cache.entries = results
	cache.stampedAt = now
	return results
end

function EggData.invalidate()
	cache.entries = {}
	cache.stampedAt = -math.huge
end

function EggData.nearby(radius, minMoney, force)
	local root = Util.getRootPart()
	if not root then
		return {}
	end

	minMoney = tonumber(minMoney) or 0
	local entries = EggData.scan(force)
	local results = {}

	for _, entry in ipairs(entries) do
		local dist = (entry.position - root.Position).Magnitude
		if (radius == nil or dist <= radius) and entry.moneyPerSec >= minMoney then
			local item = table.clone(entry)
			item.distance = dist
			table.insert(results, item)
		end
	end

	table.sort(results, function(a, b)
		return a.distance < b.distance
	end)

	return results
end

function EggData.closest(radius, minMoney)
	local list = EggData.nearby(radius, minMoney)
	return list[1]
end

-- Best egg: highest money per second (filtered by minMoney)
function EggData.bestValue(minMoney)
	minMoney = tonumber(minMoney) or 0
	local all = EggData.nearby(nil, minMoney)
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
