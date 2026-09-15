-- Modern floating toast notification system (Rayfield / Fluent style).
-- Displays rich notification cards with type icons, titles, dismiss button, and animated duration progress bar.

local ctx = ...
local Util = ctx.require("core/Util")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TweenService = game:GetService("TweenService")

local MAX_VISIBLE = 4
local LIFETIME = 3.2
local SLIDE_IN = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PROGRESS_TWEEN = TweenInfo.new(LIFETIME, Enum.EasingStyle.Linear)

local ICONS = {
	success = "✓",
	error = "✕",
	warning = "⚠",
	info = "ℹ",
}

local TITLES = {
	success = "Success",
	error = "Error",
	warning = "Warning",
	info = "Information",
}

local Notify = {}
Notify.__index = Notify

function Notify.new(parent, opts)
	opts = opts or {}
	local self = setmetatable({}, Notify)
	self.accent = opts.accent or Theme.Accent
	self.parent = parent
	self.cards = {}
	self.destroyed = false

	self.container = Builder.frame({
		Name = "NotifyContainer",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 310, 1, -32),
		BackgroundTransparency = 1,
		ZIndex = 80,
		Parent = parent,
	})

	Builder.listLayout(self.container, {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
	})

	return self
end

function Notify:_discardOldest()
	local oldest = table.remove(self.cards, 1)
	if oldest and oldest.Parent then
		oldest:Destroy()
	end
end

function Notify:_buildCard(text, kind, color)
	local iconGlyph = ICONS[kind] or ICONS.info
	local titleText = TITLES[kind] or "Frost Hub"

	local card = Builder.frame({
		Name = "ToastCard",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 0.08,
		ClipsDescendants = true,
		ZIndex = 81,
		Parent = self.container,
	})
	Builder.corner(card, 10)
	local stroke = Builder.stroke(card, {
		Color = color,
		Thickness = 1.2,
		Transparency = 0.35,
	})

	-- Left icon badge
	local iconBadge = Builder.frame({
		Name = "IconBadge",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.85,
		ZIndex = 82,
		Parent = card,
	})
	Builder.pillCorner(iconBadge)
	Builder.stroke(iconBadge, {
		Color = color,
		Thickness = 1,
		Transparency = 0.4,
	})

	Builder.label({
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.FontBold,
		TextSize = 12,
		Text = iconGlyph,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 83,
		Parent = iconBadge,
	})

	-- Content frame
	local content = Builder.frame({
		Name = "Content",
		Position = UDim2.fromOffset(42, 8),
		Size = UDim2.new(1, -66, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 82,
		Parent = card,
	})

	Builder.label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 15),
		Font = Theme.FontBold,
		TextSize = 12,
		Text = titleText,
		TextColor3 = Theme.TextMain,
		ZIndex = 83,
		Parent = content,
	})

	Builder.label({
		Name = "Message",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.FontRegular,
		TextSize = 11,
		Text = text,
		TextColor3 = Theme.TextDim,
		TextWrapped = true,
		ZIndex = 83,
		Parent = content,
	})

	-- Dismiss button (×)
	local closeBtn = Builder.button({
		Name = "CloseBtn",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -24, 0, 8),
		ZIndex = 84,
		Parent = card,
	})
	Builder.pillCorner(closeBtn)

	local closeLabel = Builder.label({
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.FontBold,
		TextSize = 12,
		Text = "×",
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 85,
		Parent = closeBtn,
	})

	closeBtn.MouseEnter:Connect(function()
		closeLabel.TextColor3 = Theme.Danger
	end)
	closeBtn.MouseLeave:Connect(function()
		closeLabel.TextColor3 = Theme.TextMuted
	end)

	-- Padding spacer at bottom so content doesn't collide with progress bar
	local spacer = Builder.frame({
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundTransparency = 1,
		ZIndex = 81,
		Parent = card,
	})

	-- Duration progress bar along bottom
	local progressBar = Builder.frame({
		Name = "ProgressBar",
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = color,
		ZIndex = 83,
		Parent = card,
	})

	table.insert(self.cards, card)
	return card, stroke, closeBtn, progressBar
end

function Notify:push(text, kind)
	if self.destroyed then
		return
	end

	kind = string.lower(tostring(kind or "info"))
	local color = Theme.colorForKind(kind)

	while #self.cards >= MAX_VISIBLE do
		self:_discardOldest()
	end

	local card, stroke, closeBtn, progressBar = self:_buildCard(tostring(text), kind, color)

	-- Initial offscreen slide-in position
	card.Position = UDim2.new(0, 60, 0, 0)
	TweenService:Create(card, SLIDE_IN, { Position = UDim2.new(0, 0, 0, 0) }):Play()

	-- Shrinking duration progress bar
	TweenService:Create(progressBar, PROGRESS_TWEEN, { Size = UDim2.new(0, 0, 0, 2) }):Play()

	local dismissed = false
	local function dismiss()
		if dismissed or not card.Parent then
			return
		end
		dismissed = true

		local outTween = TweenService:Create(card, FADE_OUT, {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 80, 0, 0),
		})
		outTween:Play()
		if stroke then
			TweenService:Create(stroke, FADE_OUT, { Transparency = 1 }):Play()
		end

		outTween.Completed:Connect(function()
			if card.Parent then
				card:Destroy()
			end
		end)

		for index, tracked in ipairs(self.cards) do
			if tracked == card then
				table.remove(self.cards, index)
				break
			end
		end
	end

	closeBtn.MouseButton1Click:Connect(dismiss)
	Util.delay(LIFETIME, dismiss)
end

function Notify:destroy()
	self.destroyed = true
	self.cards = {}
	if self.container then
		self.container:Destroy()
		self.container = nil
	end
end

return Notify
