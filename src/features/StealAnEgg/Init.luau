-- Wires the Steal An Egg modules into dedicated category tabs.

local ctx = ...
local EggData = ctx.require("features/StealAnEgg/EggData")
local Esp = ctx.require("features/StealAnEgg/Esp")
local Movement = ctx.require("features/StealAnEgg/Movement")

local DEFAULT_RANGE = 350
local MIN_RANGE = 20
local MAX_RANGE = 600

return function(hub, tabs, cleanup)
	local function notify(text, kind)
		hub:notify(text, kind)
	end

	local esp = Esp.new({ notify = notify, range = DEFAULT_RANGE })
	local movement = Movement.new({ notify = notify })

	local autoTab = tabs.autoTab or tabs
	local espTab = tabs.espTab or tabs
	local defenseTab = tabs.defenseTab or tabs
	local tpTab = tabs.tpTab or tabs
	local webhookTab = tabs.webhookTab or tabs

	local function teardown()
		esp:destroy()
		movement:stop()
		EggData.invalidate()
	end
	if autoTab._trackCleanup then
		autoTab:_trackCleanup(teardown)
	end
	cleanup.track(teardown)

	-- ------------------------------------------------------------- AUTOMATION
	autoTab:AddSection("Bypass Speed Customization (1 - 1000)")
	autoTab:AddLabel("Adjust speed for walking and auto farm.", true)

	autoTab:AddSlider("Movement Speed", 1, 1000, 60, function(value)
		movement:setSpeed(value)
	end, 1)

	autoTab:AddToggle("Speed Bypass Active", false, function(on)
		movement:toggleSpeedBypass(on)
	end)

	autoTab:AddSection("Egg Auto Farm (Anti-Cheat Safe)")

	autoTab:AddToggle("Auto Farm (Best Eggs Only)", false, function(on)
		movement:toggleAutoFarmBest(on)
	end)

	autoTab:AddToggle("Auto Farm (All Nearby Eggs)", false, function(on)
		movement:toggleAutoFarmAll(on)
	end)

	autoTab:AddSection("Instant TP to Egg (Launch Exploit)")
	autoTab:AddLabel("Grabs a nearby egg to launch off, TPs to target, and glides home.", true)

	autoTab:AddButton("Instant TP to Best Egg", function()
		movement:instantTpToEgg(EggData.bestValue())
	end)

	autoTab:AddButton("Instant TP to Closest Egg", function()
		movement:instantTpToEgg(EggData.closest())
	end)

	autoTab:AddSection("Pet & Cash Automation")

	autoTab:AddToggle("Auto Collect Offline Cash", false, function(on)
		movement:toggleAutoCash(on)
	end)

	autoTab:AddButton("Equip Best Pets", function()
		movement:equipBestPets()
	end)

	-- -------------------------------------------------------------------- ESP
	espTab:AddSection("Egg ESP (Pet Name & Money/Sec Only)")
	espTab:AddLabel("Shows only the hatching pet name and +$/s.", true)

	espTab:AddToggle("Egg ESP (Pet Name + Money/s)", false, function(on)
		esp:setEggs(on)
	end)

	espTab:AddSlider("ESP Range (studs)", MIN_RANGE, MAX_RANGE, DEFAULT_RANGE, function(value)
		esp:setRange(value)
	end)

	espTab:AddSection("Player & Trap ESP")

	espTab:AddToggle("Player ESP (Health + Box)", false, function(on)
		esp:setPlayers(on)
	end)

	espTab:AddToggle("Trap ESP (Warning Tags)", false, function(on)
		esp:setTraps(on)
	end)

	espTab:AddButton("Clear All ESP", function()
		esp:clear()
		notify("Cleared all ESP highlights", "info")
	end, true)

	-- --------------------------------------------------- DEFENSE & BYPASSES
	defenseTab:AddSection("Defense & Anti-Cheat Protection")

	defenseTab:AddToggle("Anti-Trap (Neutralize All Traps)", false, function(on)
		movement:toggleAntiTrap(on)
	end)

	defenseTab:AddToggle("Monster / Guard Bypass (Freeze NPCs)", false, function(on)
		movement:toggleMonsterBypass(on)
	end)

	defenseTab:AddToggle("Anti-Ragdoll (No Stun / Fall)", false, function(on)
		movement:toggleAntiRagdoll(on)
	end)

	defenseTab:AddButton("Neutralize Anti-Cheat (ObbyAntiTP)", function()
		movement:neutralizeAntiCheat()
		notify("Anti-cheat scripts neutralized", "success")
	end)

	defenseTab:AddSection("Diagnostics")

	defenseTab:AddButton("Scan Egg Attributes (Console F9)", function()
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

	-- ----------------------------------------------------------- TELEPORTS
	tpTab:AddSection("Map Teleports")

	tpTab:AddButton("Teleport to Base / Plot", function()
		movement:teleportToBase()
	end)

	tpTab:AddButton("Teleport to Closest Egg", function()
		movement:teleportToClosestEgg()
	end)

	tpTab:AddButton("Teleport to Best Value Egg", function()
		movement:teleportToBestEgg()
	end)

	tpTab:AddButton("Teleport to Gear Shop", function()
		movement:teleportToGearShop()
	end)

	tpTab:AddButton("Teleport to Closest Player", function()
		movement:teleportToClosestPlayer()
	end)

	-- ----------------------------------------------------------- WEBHOOK
	webhookTab:AddSection("Discord Webhook Egg Logger")
	webhookTab:AddLabel("Sends a Discord embed whenever you steal an egg!", false)

	webhookTab:AddInput("Discord Webhook URL", "https://discord.com/api/webhooks/...", "", function(url)
		movement:setWebhook(url)
		notify("Webhook URL updated", "info")
	end)

	webhookTab:AddToggle("Enable Webhook Logger", false, function(on)
		movement:toggleWebhook(on)
	end)

	webhookTab:AddButton("Send Test Webhook", function()
		movement:testWebhook()
	end)

	return {
		esp = esp,
		movement = movement,
	}
end
