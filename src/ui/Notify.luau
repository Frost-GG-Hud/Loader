-- Floating toast messages anchored to the bottom-right of the screen.
-- Lives on the ScreenGui rather than inside the window so notifications stay
-- readable while the window is minimised.

local ctx = ...
local Util = ctx.require("core/Util")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TweenService = game:GetService("TweenService")

local MAX_VISIBLE = 4
local LIFETIME = 2.6
local FADE_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Notify = {}
Notify.__index = Notify

local function tween(instance, properties)
	TweenService:Create(instance, FADE_IN, properties):Play()
end

function Notify.new(parent, opts)
	opts = opts or {}
	local self = setmetatable({}, Notify)
	self.accent = opts.accent or Theme.Accent
	self.parent = parent
	self.cards = {}
	self.counter = 0
	self.destroyed = false

	self.container = Builder.frame({
		Name = "NotifyContainer",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 290, 1, -32),
		BackgroundTransparency = 1,
		ZIndex = 40,
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

function Notify:_buildCard(text, color)
	local card = Builder.frame({
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = self.container,
	})
	Builder.corner(card, 10)
	Builder.stroke(card, {
		Color = color,
		Thickness = 1,
		Transparency = 1,
	})

	local bar = Builder.frame({
		Size = UDim2.new(0, 3, 1, -14),
		Position = UDim2.fromOffset(6, 7),
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		ZIndex = 42,
		Parent = card,
	})
	Builder.corner(bar, 3)

	local content = Builder.frame({
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -26, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 42,
		Parent = card,
	})
	Builder.padding(content, {
		PaddingTop = UDim.new(0, 9),
		PaddingBottom = UDim.new(0, 9),
	})

	local label = Builder.label({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.FontMedium,
		TextSize = 12,
		Text = text,
		TextWrapped = true,
		TextTransparency = 1,
		ZIndex = 43,
		Parent = content,
	})

	table.insert(self.cards, card)
	return card, bar, label
end

function Notify:push(text, kind)
	if self.destroyed then
		return
	end

	local color = Theme.colorForKind(kind)
	self.counter = self.counter + 1

	while #self.cards >= MAX_VISIBLE do
		self:_discardOldest()
	end

	local card, bar, label = self:_buildCard(tostring(text), color)
	local stroke = card:FindFirstChildOfClass("UIStroke")

	tween(card, { BackgroundTransparency = 0.05 })
	if stroke then
		tween(stroke, { Transparency = 0.35 })
	end
	tween(bar, { BackgroundTransparency = 0 })
	tween(label, { TextTransparency = 0 })

	Util.delay(LIFETIME, function()
		if not card.Parent then
			return
		end
		local target = TweenService:Create(card, FADE_OUT, { BackgroundTransparency = 1 })
		target:Play()
		if stroke then
			TweenService:Create(stroke, FADE_OUT, { Transparency = 1 }):Play()
		end
		TweenService:Create(bar, FADE_OUT, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, FADE_OUT, { TextTransparency = 1 }):Play()

		target.Completed:Connect(function()
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
	end)
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
