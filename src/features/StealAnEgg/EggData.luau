-- Egg discovery and value reading.
--
-- Scanning `workspace:GetDescendants()` on every ESP tick was the single most
-- expensive thing in the original hub: three separate loops each walked the
-- whole DataModel every 0.3-0.5s. Results are cached here for a short window so
-- overlapping loops share one scan.

local ctx = ...
local Util = ctx.require("core/Util")

local CACHE_TTL = 0.45

-- Game builds differ: values live either in attributes or in value objects.
-- Adjust these lists if a new build renames them (the debug scan prints what a
-- live egg actually exposes).
local VALUE_ATTRIBUTES = {
	"Income",
	"Profit",
	"MoneyPerSecond",
	"IncomePerSecond",
	"CashPerSecond",
	"Value",
	"Price",
	"Worth",
}
local VALUE_OBJECT_HINTS = { "income", "profit", "value", "worth", "cash" }
local OWNER_ATTRIBUTES = { "Owner", "OwnerId", "OwnerName", "PlotOwner", "ClaimedBy", "Claimed" }

local EggData = {}
local cache = { instances = {}, stampedAt = -math.huge }

function EggData.nameMatches(instance)
	return string.find(string.lower(instance.Name), "egg", 1, true) ~= nil
end

function EggData.isEgg(instance)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then
		return false
	end
	if EggData.nameMatches(instance) then
		return true
	end
	return instance:FindFirstChild("EggType") ~= nil or instance:GetAttribute("EggType") ~= nil
end

function EggData.worldPositionOf(instance)
	if instance:IsA("BasePart") then
		return instance.Position
	end
	if instance:IsA("Model") then
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)
		if ok then
			return pivot.Position
		end
	end
	if instance:IsA("SpawnLocation") then
		return instance.Position
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

function EggData.scan()
	local now = os.clock()
	if #cache.instances > 0 and (now - cache.stampedAt) < CACHE_TTL then
		return cache.instances
	end

	local found = {}
	for _, instance in ipairs(workspace:GetDescendants()) do
		if EggData.isEgg(instance) then
			table.insert(found, instance)
		end
	end

	cache.instances = found
	cache.stampedAt = now
	return found
end

function EggData.invalidate()
	cache.instances = {}
	cache.stampedAt = -math.huge
end

-- Eggs within `radius` of the local character, nearest first.
function EggData.nearby(radius)
	local root = Util.getRootPart()
	if not root then
		return {}
	end

	local results = {}
	for _, instance in ipairs(EggData.scan()) do
		local position = EggData.worldPositionOf(instance)
		if position then
			local distance = (position - root.Position).Magnitude
			if radius == nil or distance <= radius then
				table.insert(results, {
					instance = instance,
					position = position,
					distance = distance,
				})
			end
		end
	end

	table.sort(results, function(left, right)
		return left.distance < right.distance
	end)
	return results
end

function EggData.closest(radius)
	local nearby = EggData.nearby(radius)
	return nearby[1]
end

-- Highest-value unclaimed egg, used by the "walk to best egg" action.
function EggData.bestValue()
	local best = nil
	for _, instance in ipairs(EggData.scan()) do
		if not EggData.isClaimed(instance) then
			local value = EggData.valueOf(instance)
			if value then
				local position = EggData.worldPositionOf(instance)
				if position and (not best or value > best.value) then
					best = {
						instance = instance,
						position = position,
						value = value,
					}
				end
			end
		end
	end
	return best
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
