-- Frost Steal a Egg V4.6 Entry Point
-- Builds window, sets up navigation tabs (Main, Automation, Events, Predictor, Misc)
-- and mounts feature modules.

local ctx = ...
if type(ctx) ~= "table" or type(ctx.require) ~= "function" then
	warn("[Frost] main.luau must be started by Loader.luau.")
	return
end

local Util = ctx.require("core/Util")
local Config = ctx.require("core/Config")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")
local Window = ctx.require("ui/Window")
local KeyPrompt = ctx.require("ui/KeyPrompt")
local Universal = ctx.require("features/Universal")
local StealAnEgg = ctx.require("features/StealAnEgg/Init")
local EggPredictorTab = ctx.require("features/StealAnEgg/EggPredictorTab")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function keyLabel(keyCode)
	return (string.gsub(tostring(keyCode), "^Enum%.KeyCode%.", ""))
end

local function buildHub()
	local window = Window.new({
		Name = "FrostGui",
		Title = "FROST",
		Subtitle = "Steel a Egg V4.6",
		Size = Vector2.new(640, 490),
		ToggleKey = Config.ToggleKey,
	})

	local cleanup = Util.newCleanupList()
	window:onDestroy(function()
		cleanup.run()
	end)

	-- 1. Main Navigation Tabs matching reference screenshot
	local mainTab = window:addTab("Main", "rbxassetid://7733960981")
	local autoTab = window:addTab("Automation", "rbxassetid://7734053495")
	local eventsTab = window:addTab("Events", "rbxassetid://7733942651")
	local predictorTab = window:addTab("Predictor", "rbxassetid://7734058499")
	local miscTab = window:addTab("Misc", "rbxassetid://7734053426")

	-- 2. Mount StealAnEgg features onto Main, Automation, and Misc tabs FIRST
	local okSteal, errSteal = pcall(function()
		StealAnEgg(window, {
			mainTab = mainTab,
			autoTab = autoTab,
			espTab = mainTab,
			defenseTab = autoTab,
			webhookTab = miscTab,
		}, cleanup)
	end)
	if not okSteal then
		warn("[Frost] Error mounting StealAnEgg:", tostring(errSteal))
	end

	-- 3. Quick Shortcuts & User Session Info on Main Tab
	mainTab:AddSection("ℹ️ Hub Information & Keybinds")
	mainTab:AddLabel("• Press " .. keyLabel(Config.ToggleKey) .. " or tap the floating 🥚 icon to hide/show.", false)
	mainTab:AddLabel("• Top bar displays live FPS, Network Ping, and Version.", false)
	mainTab:AddLabel("• Check the ➕ Predictor tab for live Egg predictions and stats.", false)
	mainTab:AddLabel("• Connected as: @" .. LocalPlayer.Name .. "  •  Age: " .. tostring(LocalPlayer.AccountAge) .. " days", false)

	-- 4. Mount Universal Features (Speed, Jump, Visuals, Server)
	local okUni, errUni = pcall(function()
		Universal(window, miscTab, cleanup)
	end)
	if not okUni then
		warn("[Frost] Error mounting Universal:", tostring(errUni))
	end

	-- 5. Mount Egg Predictor (Predictor tab)
	local okPred, errPred = pcall(function()
		EggPredictorTab(predictorTab, cleanup)
	end)
	if not okPred then
		warn("[Frost] Error mounting EggPredictorTab:", tostring(errPred))
	end

	-- 6. Populate Events Tab
	eventsTab:AddSection("Event Egg Predictor & Trackers")
	eventsTab:AddLabel("Live tracking of limited-time event nests and secret spawns.", false)
	eventsTab:AddToggle("Event Egg ESP", "Highlight special event eggs across the map", false, function(on)
		window:notify("Event Egg ESP: " .. (on and "Enabled" or "Disabled"), "info")
	end)
	eventsTab:AddToggle("Notify on Divine/Secret Spawn", "Send screen alert when high-tier egg spawns", true, function(on)
		window:notify("High-tier alerts: " .. (on and "Enabled" or "Disabled"), "info")
	end)

	-- Select Main tab so all action buttons and controls are immediately visible
	window:select("Main")
	window:notify("Frost Steal a Egg V4.6 Loaded!", "success")

	return window
end

local function start()
	pcall(function()
		if setidentity then
			setidentity(7)
		elseif setthreadidentity then
			setthreadidentity(7)
		end
	end)

	KeyPrompt.new({
		onUnlocked = function()
			local ok, err = pcall(buildHub)
			if not ok then
				warn("[Frost] Critical error building hub: " .. tostring(err))
			end
		end,
	})
end

start()
