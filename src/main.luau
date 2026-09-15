-- Frost hub entry point.
-- Builds the window, registers tabs, user profile card, launcher decision, and wires feature modules.
-- Started by Loader.luau, which passes the shared context as `...`.

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

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local STEAL_AN_EGG_PLACE_ID = 107778070777162

local function keyLabel(keyCode)
	return (string.gsub(tostring(keyCode), "^Enum%.KeyCode%.", ""))
end

local function buildHub()
	local window = Window.new({
		Name = "FrostGui",
		Title = "FROST HUB",
		Subtitle = "Launcher • " .. keyLabel(Config.ToggleKey) .. " or click ❄️",
		Size = Vector2.new(590, 450),
		ToggleKey = Config.ToggleKey,
	})

	local cleanup = Util.newCleanupList()
	window:onDestroy(function()
		cleanup.run()
	end)

	-- 1. Main Launcher Tab (ALWAYS visible so user can switch between modes)
	local launcherTab = window:addTab("ℹ️ Launcher")

	-- 2. Steal An Egg Category Tabs
	local autoTab = window:addTab("🥚 Automation")
	local espTab = window:addTab("👁️ Visuals / ESP")
	local defenseTab = window:addTab("🛡️ Bypasses")
	local tpTab = window:addTab("📍 Teleports")
	local webhookTab = window:addTab("🔔 Webhooks")

	-- 3. Universal Tab
	local universalTab = window:addTab("⚡ Universal")

	-- Wire Steal An Egg
	StealAnEgg(window, {
		autoTab = autoTab,
		espTab = espTab,
		defenseTab = defenseTab,
		tpTab = tpTab,
		webhookTab = webhookTab,
	}, cleanup)

	-- Wire Universal
	Universal(window, universalTab, cleanup)

	-- Functions to show/hide tab groups
	local function setStealAnEggVisible(visible)
		autoTab:setButtonVisible(visible)
		espTab:setButtonVisible(visible)
		defenseTab:setButtonVisible(visible)
		tpTab:setButtonVisible(visible)
		webhookTab:setButtonVisible(visible)
	end

	local function setUniversalVisible(visible)
		universalTab:setButtonVisible(visible)
	end

	-- Initially, only the Launcher tab is visible on the left sidebar
	setStealAnEggVisible(false)
	setUniversalVisible(false)
	launcherTab:setButtonVisible(true)

	-- ------------------------------------------------ PROFILE CARD IN LAUNCHER
	launcherTab:AddSection("Roblox User Profile")

	local profileCardY = launcherTab:nextSlot(68, 8)
	local profileCard = Builder.frame({
		Name = "ProfileCard",
		Size = UDim2.new(1, -12, 0, 68),
		Position = UDim2.fromOffset(6, profileCardY),
		BackgroundColor3 = Theme.Card,
		Parent = launcherTab._page,
	})
	Builder.corner(profileCard, Theme.Metrics.CornerCard)
	Builder.stroke(profileCard, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.4,
	})

	-- Avatar Thumbnail
	local avatarImg = Builder.imageLabel({
		Name = "Avatar",
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.fromOffset(9, 9),
		Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150",
		Parent = profileCard,
	})
	Builder.corner(avatarImg, 8)
	Builder.stroke(avatarImg, {
		Color = Theme.Accent,
		Thickness = 1,
		Transparency = 0.3,
	})

	-- Player Names & Stats
	Builder.label({
		Name = "DisplayName",
		Size = UDim2.new(1, -74, 0, 18),
		Position = UDim2.fromOffset(68, 8),
		Font = Theme.FontBold,
		TextSize = 13,
		Text = LocalPlayer.DisplayName,
		TextColor3 = Theme.TextMain,
		Parent = profileCard,
	})

	Builder.label({
		Name = "Username",
		Size = UDim2.new(1, -74, 0, 14),
		Position = UDim2.fromOffset(68, 26),
		Font = Theme.FontRegular,
		TextSize = 11,
		Text = "@" .. LocalPlayer.Name .. "  •  ID: " .. tostring(LocalPlayer.UserId),
		TextColor3 = Theme.TextDim,
		Parent = profileCard,
	})

	Builder.label({
		Name = "AccountAge",
		Size = UDim2.new(1, -74, 0, 14),
		Position = UDim2.fromOffset(68, 44),
		Font = Theme.FontRegular,
		TextSize = 10,
		Text = "Account Age: " .. tostring(LocalPlayer.AccountAge) .. " days  •  Place ID: " .. tostring(game.PlaceId),
		TextColor3 = Theme.Accent,
		Parent = profileCard,
	})

	-- ---------------------------------------------------- LAUNCHER DECISION
	launcherTab:AddSection("Launcher Decision • Choose Mode")
	launcherTab:AddLabel("Select a feature set below. You can click 'ℹ️ Launcher' on the left anytime to switch back!", true)

	launcherTab:AddButton("🥚 Launch Steal An Egg Hub (Automation, ESP, Traps, Webhooks)", function()
		setUniversalVisible(false)
		setStealAnEggVisible(true)
		window:select("🥚 Automation")
		window:notify("Steal An Egg Hub active! Use sidebar tabs to navigate.", "success")
	end)

	launcherTab:AddButton("⚡ Launch Universal Hub (Speed, Jump, Fly, Visuals, Server)", function()
		setStealAnEggVisible(false)
		setUniversalVisible(true)
		window:select("⚡ Universal")
		window:notify("Universal Hub active!", "success")
	end)

	-- ----------------------------------------------------- INFO & SHORTCUTS
	launcherTab:AddSection("Shortcuts & Controls")
	launcherTab:AddLabel("• Press " .. keyLabel(Config.ToggleKey) .. " or tap the floating ❄️ icon to hide/show.", false)
	launcherTab:AddLabel("• Drag the top title bar to move the window anywhere on screen.", false)
	launcherTab:AddLabel("• Drag the bottom-right corner to resize.", false)

	launcherTab:AddSection("Support & Community")
	launcherTab:AddButton("Copy Discord Invite Link", function()
		local setclip = setclipboard or toclipboard or writeclipboard
		if setclip then
			setclip(Config.DiscordInvite)
			window:notify("Discord invite copied to clipboard!", "success")
		else
			window:notify("Discord: " .. Config.DiscordInvite, "info")
		end
	end)

	launcherTab:AddButton("Close Frost Hub", function()
		window:destroy()
	end, true)

	-- Open with Launcher selected by default
	window:select("ℹ️ Launcher")
	window:notify("Welcome " .. LocalPlayer.DisplayName .. "! Select a mode in Launcher.", "info")

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
