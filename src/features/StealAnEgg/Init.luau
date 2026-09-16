-- Wires the Steal An Egg modules into OMG HUB style category tabs (Light Blue Accent).
-- 2-column grid layout, zero teleportation, Pathfinding wall avoidance, and min money filter.

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

	local mainTab = tabs.mainTab or tabs.autoTab or tabs
	local autoTab = tabs.autoTab or tabs
	local espTab = tabs.espTab or mainTab
	local defenseTab = tabs.defenseTab or autoTab
	local webhookTab = tabs.webhookTab or tabs

	local function teardown()
		esp:destroy()
		movement:stop()
		EggData.invalidate()
	end
	if mainTab._trackCleanup then
		mainTab:_trackCleanup(teardown)
	end
	cleanup.track(teardown)

	-- ------------------------------------------------------------- MAIN TAB (ACTIONS & CONTROLS)
	mainTab:AddSection("⚡ Quick Actions & Safe Speed")

	mainTab:AddButton("⚡ Apply Safe Fast Speed (95) >", function()
		movement:setSpeed(95)
		movement:toggleSpeedBypass(true)
		notify("Applied safe speed: 95 (no rubberbanding)", "success")
	end)

	mainTab:AddButton("🏃 Extreme Speed (150) >", function()
		movement:setSpeed(150)
		movement:toggleSpeedBypass(true)
		notify("Applied extreme speed: 150", "warning")
	end)

	mainTab:AddButton("🛑 Stop All Automation & Reset Speed", function()
		movement:setSpeed(16)
		movement:toggleSpeedBypass(false)
		movement:toggleAutoFarmBest(false)
		movement:toggleAutoFarmAll(false)
		movement:toggleAutoTreadmill(false)
		notify("Stopped automation and reset speed to default", "info")
	end, true)

	mainTab:AddSection("🥚 Auto Steal & Automation")

	-- 2-Column Grid Row 1: Auto Steal | Auto Treadmill
	mainTab:AddToggleGrid(
		{
			title = "Auto Steal",
			desc = "Holds E, steals & deposits",
			default = false,
			onChange = function(on)
				movement:toggleAutoFarmBest(on)
			end,
		},
		{
			title = "Auto Treadmill",
			desc = "Trains speed automatically",
			default = false,
			onChange = function(on)
				movement:toggleAutoTreadmill(on)
			end,
		}
	)

	-- 2-Column Grid Row 2: Anti Knock Back | God Mode
	mainTab:AddToggleGrid(
		{
			title = "Anti Knock Back",
			desc = "Blocks chicken & animal hits",
			default = false,
			onChange = function(on)
				movement:toggleAntiKnockback(on)
			end,
		},
		{
			title = "God Mode",
			desc = "Anti-Ragdoll & knockdowns",
			default = false,
			onChange = function(on)
				movement:toggleAntiRagdoll(on)
			end,
		}
	)

	-- 2-Column Grid Row 3: Speed | Steal By Value (Input boxes)
	mainTab:AddInputGrid(
		{
			title = "Speed",
			desc = "Speed level 1 - 1000",
			placeholder = "60",
			default = "60",
			onChange = function(val)
				movement:setSpeed(tonumber(val) or 60)
			end,
		},
		{
			title = "Steal By Value",
			desc = "Min value; supports k, m, b",
			placeholder = "e.g. 1m, 500k",
			default = "0",
			onChange = function(val)
				movement:setMinMoney(val)
			end,
		}
	)

	mainTab:AddSection("Movement Speed & Bypass")

	mainTab:AddSlider("Movement Speed (1 - 1000)", 1, 1000, 60, function(value)
		movement:setSpeed(value)
	end, 1)

	mainTab:AddToggle("Speed Bypass Active (1 - 1000)", false, function(on)
		movement:toggleSpeedBypass(on)
	end)

	mainTab:AddSection("🌾 Farming & Offline Cash")

	mainTab:AddToggle("Auto Farm Highest Value Eggs First", false, function(on)
		movement:toggleAutoFarmBest(on)
	end)

	mainTab:AddToggle("Auto Farm All Nearby Eggs (Nearest First)", false, function(on)
		movement:toggleAutoFarmAll(on)
	end)

	mainTab:AddToggle("Auto Collect Offline Cash (Treadmill AFK)", false, function(on)
		movement:toggleAutoCash(on)
	end)

	mainTab:AddButton("✨ Equip Best Pets (WearBest)", function()
		movement:equipBestPets()
	end)

	-- -------------------------------------------------------------------- ESPs
	espTab:AddSection("ESPs")
	espTab:AddLabel("Above: Money / Sec  •  Below: (Egg Name) Pet Name", true)

	espTab:AddToggleGrid(
		{
			title = "Egg ESP",
			desc = "+$/s & (Egg) Pet Name",
			default = false,
			onChange = function(on)
				esp:setEggs(on)
			end,
		},
		{
			title = "Trap ESP",
			desc = "Warning tags on traps",
			default = false,
			onChange = function(on)
				esp:setTraps(on)
			end,
		}
	)

	espTab:AddToggle("Player ESP (Health + Box)", false, function(on)
		esp:setPlayers(on)
	end)

	espTab:AddSlider("ESP Range (studs)", MIN_RANGE, MAX_RANGE, DEFAULT_RANGE, function(value)
		esp:setRange(value)
	end)

	espTab:AddButton("Clear All ESP", function()
		esp:clear()
		notify("Cleared all ESP highlights", "info")
	end, true)

	-- --------------------------------------------------- PROTECTION
	defenseTab:AddSection("Protection & Bypasses")

	defenseTab:AddToggleGrid(
		{
			title = "Anti-Trap",
			desc = "Walk through all traps",
			default = false,
			onChange = function(on)
				movement:toggleAntiTrap(on)
			end,
		},
		{
			title = "Monster Bypass",
			desc = "Freezes NPCs & hitboxes",
			default = false,
			onChange = function(on)
				movement:toggleMonsterBypass(on)
			end,
		}
	)

	defenseTab:AddButton("Neutralize Anti-Cheat (ObbyAntiTP)", function()
		movement:neutralizeAntiCheat()
		notify("Anti-cheat scripts neutralized", "success")
	end)

	defenseTab:AddButton("Scan Egg Attributes (Console F9)", function()
		local sample = nil
		for _, entry in ipairs(EggData.scan(true)) do
			sample = entry.model or entry.instance
			if sample and sample:IsA("Instance") then
				break
			end
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

	-- ----------------------------------------------------------- WEBHOOK
	webhookTab:AddSection("Discord Webhook Egg Logger")
	webhookTab:AddLabel("Sends clean pet name, rarity, and money/sec to your Discord!", false)

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
