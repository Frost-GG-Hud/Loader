-- Frost hub entry point.
-- Builds the window, registers the tabs, and wires up feature modules.
-- Started by Loader.luau, which passes the shared context as `...`.

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
		Title = "FROST HUB",
		Subtitle = "Steal An Egg • " .. keyLabel(Config.ToggleKey) .. " or click ❄️",
		Size = Vector2.new(580, 440),
		ToggleKey = Config.ToggleKey,
	})

	local cleanup = Util.newCleanupList()
	window:onDestroy(function()
		cleanup.run()
	end)

	-- 1. Steal An Egg Tab (Primary & Loaded Immediately)
	local eggTab = window:addTab("🥚 Steal An Egg")
	StealAnEgg(window, eggTab, cleanup)

	-- 2. Universal Tab (Movement, Fly, Visuals, Server)
	local universalTab = window:addTab("⚡ Universal")
	Universal(window, universalTab, cleanup)

	-- 3. Info & Settings Tab
	local infoTab = window:addTab("ℹ️ Info")
	infoTab:AddSection("Game Information")
	infoTab:AddLabel("Game: Steal An Egg (ID: " .. tostring(game.PlaceId) .. ")", false)
	if game.PlaceId == STEAL_AN_EGG_PLACE_ID then
		infoTab:AddLabel("Status: Verified PlaceId match", false)
	else
		infoTab:AddLabel("Status: Running in custom / alternate place", true)
	end

	infoTab:AddSection("Shortcuts & Controls")
	infoTab:AddLabel("• Press " .. keyLabel(Config.ToggleKey) .. " or tap the floating ❄️ icon to hide/show.", false)
	infoTab:AddLabel("• Drag the top title bar to move the window.", false)
	infoTab:AddLabel("• Drag bottom-right corner to resize.", false)

	infoTab:AddSection("Community & Support")
	infoTab:AddButton("Copy Discord Invite Link", function()
		local setclip = setclipboard or toclipboard or writeclipboard
		if setclip then
			setclip(Config.DiscordInvite)
			window:notify("Discord invite copied to clipboard!", "success")
		else
			window:notify("Discord: " .. Config.DiscordInvite, "info")
		end
	end)

	infoTab:AddButton("Close Frost Hub", function()
		window:destroy()
	end, true)

	window:select("🥚 Steal An Egg")
	window:notify("Frost Hub loaded! Steal An Egg features ready.", "success")

	return window
end

local function start()
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
