-- Frost hub entry point.
--
-- This file used to be a ~1000 line monolith containing the window library, the
-- widgets, the key gate and every game feature. It is now a thin orchestrator:
-- it builds the window, registers the tabs, and hands each feature module the
-- hub plus a cleanup list. Everything else lives in src/core, src/ui and
-- src/features.
--
-- It is started by Loader.luau, which passes the shared context as `...`.

local ctx = ...
if type(ctx) ~= "table" or type(ctx.require) ~= "function" then
	warn("[Frost] main.luau must be started by Loader.luau.")
	return
end

local Util = ctx.require("core/Util")
local Config = ctx.require("core/Config")
local Window = ctx.require("ui/Window")
local KeyPrompt = ctx.require("ui/KeyPrompt")
local Universal = ctx.require("features/Universal")
local StealAnEgg = ctx.require("features/StealAnEgg/Init")

local STEAL_AN_EGG_PLACE_ID = 107778070777162

local function keyLabel(keyCode)
	return (string.gsub(tostring(keyCode), "^Enum%.KeyCode%.", ""))
end

local function buildHub()
	local window = Window.new({
		Name = "FrostGui",
		Title = "Frost",
		Subtitle = "Drag the title bar to move - " .. keyLabel(Config.ToggleKey) .. " to show/hide",
		Size = Vector2.new(560, 460),
		ToggleKey = Config.ToggleKey,
	})

	-- Anything the feature modules start (fly, noclip, ESP loops, walkers) is
	-- registered here and torn down with the window.
	local cleanup = Util.newCleanupList()
	window:onDestroy(function()
		cleanup.run()
	end)

	local universalTab = window:addTab("Universal")
	Universal(window, universalTab, cleanup)

	local gameTab = window:addTab("Steal An Egg")
	gameTab:AddLabel("Open the Information tab and press 'Load Steal An Egg Features'.", true)

	local informationTab = window:addTab("Information")
	informationTab:AddLabel("Pick a game to load its feature set.", true)
	informationTab:AddLabel("Current PlaceId: " .. tostring(game.PlaceId), true)

	if game.PlaceId == STEAL_AN_EGG_PLACE_ID then
		informationTab:AddLabel("Steal An Egg detected - its features are ready to load.", true)
	else
		informationTab:AddLabel("No dedicated feature set matches this PlaceId; the game tab loads Steal An Egg anyway.", true)
	end

	informationTab:AddButton("Load Steal An Egg Features", function()
		-- Clear first: this is what stops the previous ESP loops and walkers.
		gameTab:Clear()
		StealAnEgg(window, gameTab, cleanup)
		window:select("Steal An Egg")

		if game.PlaceId == STEAL_AN_EGG_PLACE_ID then
			window:notify("Steal An Egg features loaded", "success")
		else
			window:notify("Loaded Steal An Egg features (untested in this game)", "warning")
		end
	end)

	informationTab:AddButton("Reset Game Tab", function()
		gameTab:Clear()
		gameTab:AddLabel("Open the Information tab and press 'Load Steal An Egg Features'.", true)
		window:select("Universal")
		window:notify("Game features unloaded", "info")
	end, true)

	informationTab:AddLabel("Universal features work everywhere. Game features only make sense in the game they were written for.", true)

	window:select("Information")
	window:notify("Frost ready. Drag the title bar to move the window.", "success")

	return window
end

local function start()
	-- Raise the script identity first so gethui/ScreenGui use is not restricted.
	pcall(function()
		if setidentity then
			setidentity(8)
		end
	end)

	KeyPrompt.new({
		onUnlocked = function()
			buildHub()
		end,
	})
end

start()
