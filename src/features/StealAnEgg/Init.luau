-- Wires the Steal An Egg modules into the dedicated game tab.

local ctx = ...
local EggData = ctx.require("features/StealAnEgg/EggData")
local Esp = ctx.require("features/StealAnEgg/Esp")
local Movement = ctx.require("features/StealAnEgg/Movement")

local DEFAULT_RANGE = 250
local MIN_RANGE = 20
local MAX_RANGE = 600

return function(hub, tab, cleanup)
	local function notify(text, kind)
		hub:notify(text, kind)
	end

	local esp = Esp.new({ notify = notify, range = DEFAULT_RANGE })
	local movement = Movement.new({ notify = notify })

	local function teardown()
		esp:destroy()
		movement:stop()
		EggData.invalidate()
	end
	tab:_trackCleanup(teardown)
	cleanup.track(teardown)

	-- ------------------------------------------------------------- AUTOMATION
	tab:AddSection("Egg Automation")

	tab:AddToggle("Auto Farm (Walk & Deposit)", false, function(on)
		movement:toggleAutoFarm(on, false)
	end)

	tab:AddToggle("Fast Auto Farm (Instant TP)", false, function(on)
		movement:toggleAutoFarm(on, true)
	end)

	tab:AddButton("Instant Steal Nearest Egg", function()
		movement:instantStealNearest()
	end)

	tab:AddToggle("Auto Collect Offline Cash", false, function(on)
		movement:toggleAutoCash(on)
	end)

	tab:AddButton("Equip Best Pets", function()
		movement:equipBestPets()
	end)

	-- --------------------------------------------------- DEFENSE & BYPASSES
	tab:AddSection("Defense & Bypasses")

	tab:AddToggle("Anti-Trap (Bypass All Traps)", false, function(on)
		movement:toggleAntiTrap(on)
	end)

	tab:AddToggle("Monster / Guard Bypass", false, function(on)
		movement:toggleMonsterBypass(on)
	end)

	tab:AddToggle("Anti-Ragdoll (No Stun / Fall)", false, function(on)
		movement:toggleAntiRagdoll(on)
	end)

	-- ------------------------------------------------------------- VISUALS
	tab:AddSection("ESP & Visuals")

	tab:AddToggle("Egg ESP (Rarity + Distance)", false, function(on)
		esp:setEggs(on)
	end)

	tab:AddSlider("Egg ESP Range (studs)", MIN_RANGE, MAX_RANGE, DEFAULT_RANGE, function(value)
		esp:setRange(value)
	end)

	tab:AddToggle("Player ESP (Health + Box)", false, function(on)
		esp:setPlayers(on)
	end)

	tab:AddToggle("Trap ESP (Warning)", false, function(on)
		esp:setTraps(on)
	end)

	-- ----------------------------------------------------------- TELEPORTS
	tab:AddSection("Fast Teleports")

	tab:AddButton("Teleport to Base / Plot", function()
		movement:teleportToBase()
	end)

	tab:AddButton("Teleport to Closest Egg", function()
		movement:teleportToClosestEgg()
	end)

	tab:AddButton("Teleport to Best Value Egg", function()
		movement:teleportToBestEgg()
	end)

	tab:AddButton("Teleport to Gear Shop", function()
		movement:teleportToGearShop()
	end)

	tab:AddButton("Teleport to Closest Player", function()
		movement:teleportToClosestPlayer()
	end)

	-- ---------------------------------------------------------------- TOOLS
	tab:AddSection("Tools & Diagnostics")

	tab:AddButton("Scan Egg Attributes (Console F9)", function()
		local sample = nil
		for _, instance in ipairs(EggData.scan(true)) do
			sample = instance
			break
		end

		if not sample then
			notify("No egg objects currently found", "error")
			return
		end

		local attributes, children = EggData.describe(sample)
		print("[Frost] Sample egg:", sample:GetFullName())
		print("[Frost] Attributes:", attributes)
		print("[Frost] Children:", children)
		notify("Printed sample egg attributes to F9 console", "info")
	end)

	tab:AddButton("Clear All ESP", function()
		esp:clear()
		notify("Cleared all ESP highlights", "info")
	end, true)
end
