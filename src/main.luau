-- Ajjans Steal an Egg V4.6 Entry Point
-- Builds window, sets up navigation tabs (Main, Automation, Events, Predictor, Misc)
-- and mounts feature modules.

local ctx = ...
if type(ctx) ~= "table" or type(ctx.require) ~= "function" then
	warn("[Ajjans] main.luau must be started by Loader.luau.")
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
	local mainTab = window:addTab("🏠 Main")
	local autoTab = window:addTab("⚙️ Automation")
	local eventsTab = window:addTab("🎁 Events")
	local predictorTab = window:addTab("➕ Predictor")
	local miscTab = window:addTab("⚙️ Misc")

	-- 2. Mount Egg Predictor (Screenshot feature)
	EggPredictorTab(predictorTab, cleanup)

	-- 3. Mount Automation Features (Auto Steal, Speed, Treadmill, Anti-Knockback, God Mode)
	StealAnEgg(window, {
		autoTab = autoTab,
		espTab = mainTab,
		defenseTab = autoTab,
		webhookTab = miscTab,
	}, cleanup)

	-- 4. Mount Universal Features (Speed, Jump, Visuals, Server)
	Universal(window, miscTab, cleanup)

	-- 5. Populate Main Tab (Dashboard & Profile)
	mainTab:AddSection("Roblox User Profile")
	local profileCardY = mainTab:nextSlot(68, 8)
	local profileCard = Builder.frame({
		Name = "ProfileCard",
		Size = UDim2.new(1, -12, 0, 68),
		Position = UDim2.fromOffset(6, profileCardY),
		BackgroundColor3 = Theme.Card,
		Parent = mainTab._page,
	})
	Builder.corner(profileCard, Theme.Metrics.CornerCard)
	Builder.stroke(profileCard, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.4,
	})

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

	mainTab:AddSection("Quick Shortcuts & Info")
	mainTab:AddLabel("• Press " .. keyLabel(Config.ToggleKey) .. " or tap the floating 🥚 icon to hide/show.", false)
	mainTab:AddLabel("• Top bar displays live FPS, Network Ping, and Version.", false)
	mainTab:AddLabel("• Check the ➕ Predictor tab for live Egg predictions and stats.", false)

	-- 6. Populate Events Tab
	eventsTab:AddSection("Event Egg Predictor & Trackers")
	eventsTab:AddLabel("Live tracking of limited-time event nests and secret spawns.", false)
	eventsTab:AddToggle("Event Egg ESP", "Highlight special event eggs across the map", false, function(on)
		window:notify("Event Egg ESP: " .. (on and "Enabled" or "Disabled"), "info")
	end)
	eventsTab:AddToggle("Notify on Divine/Secret Spawn", "Send screen alert when high-tier egg spawns", true, function(on)
		window:notify("High-tier alerts: " .. (on and "Enabled" or "Disabled"), "info")
	end)

	-- Default to Predictor tab matching the user's reference image
	window:select("➕ Predictor")
	window:notify("Frost Steal a Egg V4.6 Loaded!", "success")

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
