-- Action row: a card with a full-width click target and an accent underline.
--
-- The old version built one tween per button with a hard-coded goal and called
-- :Cancel() on mouse-leave. Rapidly entering/leaving left the underline stuck
-- part way across the card. Tweens are created on demand here instead, so every
-- hover state resolves cleanly.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TweenService = game:GetService("TweenService")

local HOVER_IN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HEIGHT = 39
local GAP = 8
local UNDERLINE = 3

return function(tab, text, callback, danger)
	local accent = danger and Theme.Danger or tab._accent
	local y = tab:nextSlot(HEIGHT, GAP)

	local card = Builder.frame({
		Name = "ActionRow",
		Size = UDim2.new(1, -12, 0, HEIGHT),
		Position = UDim2.fromOffset(6, y),
		BackgroundColor3 = Theme.Card,
		Parent = tab._page,
	})
	Builder.corner(card, Theme.Metrics.CornerCard)

	local label = Builder.button({
		Name = "Hit",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Text = tostring(text),
		Font = Theme.FontMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = danger and Theme.Danger or Theme.TextMain,
		Parent = card,
	})

	local underline = Builder.frame({
		Name = "Underline",
		Size = UDim2.new(0, 0, 0, UNDERLINE),
		Position = UDim2.new(0, 0, 1, -UNDERLINE),
		BackgroundColor3 = accent,
		Parent = card,
	})
	Builder.corner(underline, UNDERLINE)

	local function setUnderline(width, info)
		TweenService:Create(underline, info, {
			Size = UDim2.new(width, 0, 0, UNDERLINE),
		}):Play()
	end

	label.MouseEnter:Connect(function()
		setUnderline(1, HOVER_IN)
		TweenService:Create(card, HOVER_IN, { BackgroundColor3 = Theme.CardHover }):Play()
	end)

	label.MouseLeave:Connect(function()
		setUnderline(0, HOVER_OUT)
		TweenService:Create(card, HOVER_OUT, { BackgroundColor3 = Theme.Card }):Play()
	end)

	label.MouseButton1Click:Connect(function()
		if not callback then
			return
		end
		local ok, err = pcall(callback)
		if not ok then
			tab:_notify("Error: " .. tostring(err), "error")
		end
	end)

	if tab.registerWidget then
		tab:registerWidget(card, HEIGHT, GAP, text)
	end

	return { _card = card, _label = label }
end
