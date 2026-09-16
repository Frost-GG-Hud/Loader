-- The modal key gate shown before the hub exists (Rayfield / Fluent style).
-- Features:
--  * Auto-login persistence via executor filesystem (`frost_key.txt`).
--  * "Paste from Clipboard" button for mobile & desktop convenience.
--  * HTTP fallback verification via core/Http.
--  * Modern glowing card aesthetics and status feedback.

local ctx = ...
local Util = ctx.require("core/Util")
local Config = ctx.require("core/Config")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")
local Http = ctx.require("core/Http")

local M = Theme.Metrics

local CARD_WIDTH = 420
local CARD_HEIGHT = 330
local SET_CLIPBOARD_NAMES = { "setclipboard", "toclipboard", "writeclipboard", "set_clipboard" }
local GET_CLIPBOARD_NAMES = { "getclipboard", "get_clipboard", "fromclipboard", "getClipboard" }
local KEY_STORAGE_FILE = "frost_key.txt"

local KeyPrompt = {}
KeyPrompt.__index = KeyPrompt

local function copyToClipboard(text)
	local namespaces = {}
	if getfenv then table.insert(namespaces, getfenv()) end
	if getgenv then table.insert(namespaces, getgenv()) end
	table.insert(namespaces, _G)

	for _, namespace in ipairs(namespaces) do
		if type(namespace) == "table" then
			for _, name in ipairs(SET_CLIPBOARD_NAMES) do
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

local function getFromClipboard()
	local namespaces = {}
	if getfenv then table.insert(namespaces, getfenv()) end
	if getgenv then table.insert(namespaces, getgenv()) end
	table.insert(namespaces, _G)

	for _, namespace in ipairs(namespaces) do
		if type(namespace) == "table" then
			for _, name in ipairs(GET_CLIPBOARD_NAMES) do
				local fn = namespace[name]
				if type(fn) == "function" then
					local ok, res = pcall(fn)
					if ok and type(res) == "string" and #res > 0 then
						return res
					end
				end
			end
		end
	end
	return nil
end

local function loadSavedKey()
	local ok, res = pcall(function()
		local read = readfile or (syn and syn.readfile)
		if read then
			return read(KEY_STORAGE_FILE)
		end
		return nil
	end)
	if ok and type(res) == "string" and #res > 0 then
		return res
	end
	return nil
end

local function saveKeyLocally(key)
	pcall(function()
		local write = writefile or (syn and syn.writefile)
		if write then
			write(KEY_STORAGE_FILE, tostring(key))
		end
	end)
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
		BackgroundTransparency = 0.52,
		ZIndex = 1,
		Parent = self.screenGui,
	})
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
		Thickness = 1.4,
		Transparency = 0.3,
	})

	local glow = Builder.frame({
		Name = "Glow",
		Size = UDim2.new(1, -30, 0, 58),
		Position = UDim2.fromOffset(15, 14),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0.92,
		ZIndex = 3,
		Parent = card,
	})
	Builder.corner(glow, 14)

	Builder.label({
		Size = UDim2.new(1, -40, 0, 26),
		Position = UDim2.fromOffset(20, 20),
		Font = Theme.FontBold,
		TextSize = 20,
		Text = "AJJANS KEY SYSTEM",
		TextColor3 = Theme.Accent,
		ZIndex = 4,
		Parent = card,
	})

	Builder.label({
		Size = UDim2.new(1, -40, 0, 16),
		Position = UDim2.fromOffset(20, 48),
		Font = Theme.FontRegular,
		TextSize = 11,
		Text = "Steal an Egg V4.6  •  Get key in Discord via /key",
		TextColor3 = Theme.TextDim,
		ZIndex = 4,
		Parent = card,
	})

	-- Input Row Container (TextBox + Paste Button)
	local inputRow = Builder.frame({
		Name = "InputRow",
		Size = UDim2.new(1, -40, 0, 42),
		Position = UDim2.fromOffset(20, 78),
		BackgroundColor3 = Theme.Surface,
		ZIndex = 4,
		Parent = card,
	})
	Builder.corner(inputRow, 10)
	local inputStroke = Builder.stroke(inputRow, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.4,
	})

	local box = Builder.new("TextBox", {
		Name = "KeyInput",
		Size = UDim2.new(1, -78, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Font = Theme.FontBold,
		TextSize = 13,
		Text = "",
		PlaceholderText = "Paste or enter key here...",
		PlaceholderColor3 = Theme.TextMuted,
		TextColor3 = Theme.TextMain,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 5,
		Parent = inputRow,
	})

	local pasteBtn = Builder.new("TextButton", {
		Name = "PasteBtn",
		Size = UDim2.fromOffset(58, 28),
		Position = UDim2.new(1, -64, 0.5, -14),
		BackgroundColor3 = Theme.SurfaceAlt,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Theme.FontMedium,
		TextSize = 11,
		TextColor3 = Theme.Accent,
		Text = "📋 Paste",
		ZIndex = 6,
		Parent = inputRow,
	})
	Builder.corner(pasteBtn, 6)
	Builder.stroke(pasteBtn, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.4,
	})

	local status = Builder.label({
		Name = "Status",
		Size = UDim2.new(1, -40, 0, 32),
		Position = UDim2.fromOffset(20, 126),
		Font = Theme.FontMedium,
		TextSize = 11,
		Text = "",
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Center,
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
		Position = UDim2.fromOffset(20, 164),
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
		TextSize = 13,
		TextColor3 = Theme.White,
		Text = "Unlock Hub",
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
		Font = Theme.FontMedium,
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
		Position = UDim2.fromOffset(20, 208),
		BackgroundColor3 = Theme.AccentDark,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Theme.FontMedium,
		TextSize = 12,
		TextColor3 = Theme.White,
		Text = "Get Free Key - Copy Discord Invite",
		ZIndex = 5,
		Parent = card,
	})
	Builder.corner(getKeyBtn, 9)

	Builder.label({
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 250),
		Font = Theme.FontRegular,
		TextSize = 10,
		Text = "Get the free key in our Discord via /key command",
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 4,
		Parent = card,
	})

	local function setBusy(busy)
		self.busy = busy
		unlockBtn.Active = not busy
		retryBtn.Active = not busy
		unlockBtn.Text = busy and "Checking..." or "Unlock Hub"
	end

	local function attempt()
		if self.busy or self.destroyed then
			return
		end

		local entered = Util.normalizeKey(box.Text)
		if entered == "" then
			setStatus("Please enter or paste your key from /key first.", Theme.Warning)
			return
		end

		setBusy(true)
		setStatus("Checking key with GitHub...")

		Util.spawn(function()
			local serverKey = Http.getLiveKey(Config.KeyFile)

			if not serverKey then
				setBusy(false)
				setStatus("Could not reach GitHub for verification. Check internet & try Re-check.", Theme.Danger)
				return
			end

			if Util.normalizeKey(serverKey) ~= entered then
				setBusy(false)
				setStatus(
					string.format("Invalid key (%d chars). Check /key in our Discord for the current key.", #entered),
					Theme.Danger
				)
				return
			end

			setStatus("Key accepted! Saving session & loading Frost Hub...", Theme.Success)
			saveKeyLocally(entered)

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

	pasteBtn.MouseButton1Click:Connect(function()
		local clipText = getFromClipboard()
		if clipText and #clipText > 0 then
			box.Text = clipText
			setStatus("Key pasted from clipboard!", Theme.Success)
		else
			setStatus("Clipboard is empty or unsupported on this executor.", Theme.Warning)
		end
	end)

	unlockBtn.MouseButton1Click:Connect(attempt)
	retryBtn.MouseButton1Click:Connect(attempt)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			attempt()
		end
	end)

	getKeyBtn.MouseButton1Click:Connect(function()
		if copyToClipboard(Config.DiscordInvite) then
			setStatus("Discord invite copied to clipboard!", Theme.Success)
		else
			setStatus("Discord: " .. Config.DiscordInvite, Theme.Accent)
		end
	end)

	-- Auto-login check: read saved key if present
	local saved = loadSavedKey()
	if saved and #saved > 0 then
		box.Text = saved
		setStatus("Saved key detected! Auto-verifying...", Theme.Accent)
		Util.delay(0.3, attempt)
	end

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
