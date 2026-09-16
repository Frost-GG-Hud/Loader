-- Paragraph / Info card widget (Fluent / Rayfield style).
-- Displays structured, multiline informational text, updates, or instructions in a clean card.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TextService = game:GetService("TextService")

local GAP = 8
local HORIZONTAL_PADDING = 24
local MIN_HEIGHT = 44

local function measureContentHeight(text, width)
	local ok, measured = pcall(function()
		return TextService:GetTextSize(
			text,
			11,
			Theme.FontRegular,
			Vector2.new(math.max(width, 1), math.huge)
		)
	end)
	if ok and measured then
		return math.max(16, measured.Y + 4)
	end
	return 20
end

return function(tab, titleText, contentText)
	titleText = tostring(titleText or "")
	contentText = tostring(contentText or "")

	local width = tab:contentWidth() - 12
	local bodyW = math.max(60, width - HORIZONTAL_PADDING)
	local contentH = measureContentHeight(contentText, bodyW)
	local totalH = math.max(MIN_HEIGHT, 26 + contentH + 10)

	local y = tab:nextSlot(totalH, GAP)

	local card = Builder.frame({
		Name = "ParagraphCard",
		Size = UDim2.new(1, -12, 0, totalH),
		Position = UDim2.fromOffset(6, y),
		BackgroundColor3 = Theme.Card,
		Parent = tab._page,
	})
	Builder.corner(card, Theme.Metrics.CornerCard)
	Builder.stroke(card, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.5,
	})

	local titleLabel = Builder.label({
		Name = "Title",
		Size = UDim2.new(1, -HORIZONTAL_PADDING, 0, 18),
		Position = UDim2.fromOffset(12, 8),
		Font = Theme.FontBold,
		TextSize = 12,
		Text = titleText,
		TextColor3 = Theme.TextMain,
		Parent = card,
	})

	local bodyLabel = Builder.label({
		Name = "Content",
		Size = UDim2.new(1, -HORIZONTAL_PADDING, 0, contentH),
		Position = UDim2.fromOffset(12, 28),
		Font = Theme.FontRegular,
		TextSize = 11,
		Text = contentText,
		TextColor3 = Theme.TextDim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})

	local function updateHeight()
		local w = tab:contentWidth() - 12
		local bw = math.max(60, w - HORIZONTAL_PADDING)
		local ch = measureContentHeight(bodyLabel.Text, bw)
		local th = math.max(MIN_HEIGHT, 26 + ch + 10)
		totalH = th
		card.Size = UDim2.new(1, -12, 0, th)
		bodyLabel.Size = UDim2.new(1, -HORIZONTAL_PADDING, 0, ch)
		if tab.relayout then
			tab:relayout()
		end
	end

	if tab.registerWidget then
		tab:registerWidget(card, totalH, GAP, titleText .. " " .. contentText, function()
			return totalH
		end)
	end

	return {
		SetTitle = function(text)
			titleText = tostring(text or "")
			titleLabel.Text = titleText
		end,
		SetContent = function(text)
			contentText = tostring(text or "")
			bodyLabel.Text = contentText
			updateHeight()
		end,
		_card = card,
	}
end
