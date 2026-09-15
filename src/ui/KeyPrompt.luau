-- The modal key gate shown before the hub exists.
--
-- Fixes over the original prompt:
--  * it reads the key through core/Http, which actually resolves on every
--    executor instead of silently relying on `HttpService:HttpGet`;
--  * a `busy` latch plus disabling the button stops a double click from firing
--    two fetches and building two hubs;
--  * the pointless fixed 0.3s delay on "Re-check Key" is gone;
--  * network failure and a wrong key now report different messages;
--  * the status line is tall enough for two wrapped lines, so the message can
--    no longer be clipped;
--  * clipboard support covers the names executors actually ship.

local ctx = ...
local Util = ctx.require("core/Util")
local Config = ctx.require("core/Config")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")
local Http = ctx.require("core/Http")

local M = Theme.Metrics

local CARD_WIDTH = 400
local CARD_HEIGHT = 300
local CLIPBOARD_NAMES = { "setclipboard", "toclipboard", "writeclipboard", "set_clipboard" }

local KeyPrompt = {}
KeyPrompt.__index = KeyPrompt

local function copyToClipboard(text)
	local namespaces = {}
	if getfenv then
		table.insert(namespaces, getfenv())
	end
	if getgenv then
		table.insert(namespaces, getgenv())
	end
	table.insert(namespaces, _G)

	for _, namespace in ipairs(namespaces) do
		if type(namespace) == "table" then
			for _, name in ipairs(CLIPBOARD_NAMES) do
				local fn = namespace[name]
				if type(fn) == "function" then
					if pcall(fn, text) then
						return true
					end
				end
			end
		end
	end
	return false
end

function KeyPrompt.new(config)
	local self = setmetatable({}, KeyPrompt)

	self.busy = false
	self.destroyed = false
	self.onUnlocked = config.onUnlocked
	self.screenGui = Util.newScreenGui("FrostAuth", 140)

	local backdrop = Builder.frame({
		Name = "Backdrop",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.58,
		ZIndex = 1,
		Parent = self.screenGui,
	})
	-- Clicking the dim area does nothing: this is a gate, not a dismissible panel.
	Builder.makeInteractive(backdrop)

	local card = Builder.frame({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
		BackgroundColor3 = Theme.Window,
		ZIndex = 2,
		Parent = self.screenGui,
	})
	Builder.corner(card, M.CornerWindow)
	Builder.stroke(card, {
		Color = Theme.Accent,
		Thickness = 1.2,
		Transparency = 0.32,
	})

	local glow = Builder.frame({
		Name = "Glow",
		Size = UDim2.new(1, -30, 0, 58),
		Position = UDim2.fromOffset(15, 14),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0.9,
		ZIndex = 3,
		Parent = card,
	})
	Builder.corner(glow, 14)

	Builder.label({
		Size = UDim2.new(1, -40, 0, 28),
		Position = UDim2.fromOffset(20, 22),
		Font = Theme.FontBold,
		TextSize = 22,
		Text = "Frost",
		TextColor3 = Theme.TextMain,
		ZIndex = 4,
		Parent = card,
	})

	Builder.label({
		Size = UDim2.new(1, -40, 0, 18),
		Position = UDim2.fromOffset(20, 52),
		Font = Theme.FontRegular,
		TextSize = 12,
		Text = "Enter your key to continue",
		TextColor3 = Theme.TextDim,
		ZIndex = 4,
		Parent = card,
	})

	local box = Builder.new("TextBox", {
		Name = "KeyInput",
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(20, 86),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Font = Theme.FontBold,
		TextSize = 15,
		Text = "",
		PlaceholderText = "FREEKEY-XXXX-XXXX",
		PlaceholderColor3 = Theme.TextMuted,
		TextColor3 = Theme.TextMain,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		ZIndex = 4,
		Parent = card,
	})
	Builder.corner(box, 10)

	local status = Builder.label({
		Name = "Status",
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.fromOffset(20, 132),
		Font = Theme.FontRegular,
		TextSize = 12,
		Text = "",
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Theme.TextDim,
		ZIndex = 4,
		Parent = card,
	})

	local function setStatus(text, color)
		status.Text = text
		status.TextColor3 = color or Theme.TextDim
	end

	local row = Builder.frame({
		Size = UDim2.new(1, -40, 0, 36),
		Position = UDim2.fromOffset(20, 172),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = card,
	})

	local unlockBtn = Builder.new("TextButton", {
		Name = "Unlock",
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.White,
		Text = "Unlock",
		ZIndex = 5,
		Parent = row,
	})
	Builder.corner(unlockBtn, 9)

	local retryBtn = Builder.new("TextButton", {
		Name = "Recheck",
		Position = UDim2.new(0.5, 4, 0, 0),
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Theme.FontRegular,
		TextSize = 13,
		TextColor3 = Theme.TextMain,
		Text = "Re-check Key",
		ZIndex = 5,
		Parent = row,
	})
	Builder.corner(retryBtn, 9)

	local getKeyBtn = Builder.new("TextButton", {
		Name = "GetKey",
		Size = UDim2.new(1, -40, 0, 34),
		Position = UDim2.fromOffset(20, 216),
		BackgroundColor3 = Theme.AccentDark,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Theme.FontMedium,
		TextSize = 13,
		TextColor3 = Theme.White,
		Text = "Get Key - Copy Discord Invite",
		ZIndex = 5,
		Parent = card,
	})
	Builder.corner(getKeyBtn, 9)

	Builder.label({
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 258),
		Font = Theme.FontRegular,
		TextSize = 11,
		Text = "Get the free key with /key in our Discord (role required)",
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})

	local function setBusy(busy)
		self.busy = busy
		unlockBtn.Active = not busy
		retryBtn.Active = not busy
		unlockBtn.Text = busy and "Checking..." or "Unlock"
	end

	local function attempt()
		if self.busy or self.destroyed then
			return
		end

		local entered = Util.normalizeKey(box.Text)
		if entered == "" then
			setStatus("Enter the key from /key in our Discord first.", Theme.Warning)
			return
		end

		setBusy(true)
		setStatus("Checking the key against GitHub...")

		Util.spawn(function()
			local serverKey = Http.getLiveKey(Config.KeyFile)

			if not serverKey then
				setBusy(false)
				setStatus("Could not reach GitHub for the key list. Check your connection and try Re-check.", Theme.Danger)
				return
			end

			if Util.normalizeKey(serverKey) ~= entered then
				setBusy(false)
				setStatus(
					string.format("Invalid key (%d characters). Run /key in our Discord for the current one.", #entered),
					Theme.Danger
				)
				return
			end

			setStatus("Key accepted. Opening the hub...", Theme.Success)

			local ok, err = pcall(self.onUnlocked)
			if ok then
				self:destroy()
			else
				setBusy(false)
				setStatus("Hub failed to start: " .. tostring(err), Theme.Danger)
				warn("[Frost] Hub failed to start: " .. tostring(err))
			end
		end)
	end

	unlockBtn.MouseButton1Click:Connect(attempt)
	retryBtn.MouseButton1Click:Connect(attempt)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			attempt()
		end
	end)

	getKeyBtn.MouseButton1Click:Connect(function()
		if copyToClipboard(Config.DiscordInvite) then
			setStatus("Discord invite copied. Paste it into Discord or your browser.", Theme.Success)
		else
			setStatus("Discord invite: " .. Config.DiscordInvite, Theme.Accent)
		end
	end)

	return self
end

function KeyPrompt:destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.screenGui then
		self.screenGui:Destroy()
		self.screenGui = nil
	end
end

return KeyPrompt
