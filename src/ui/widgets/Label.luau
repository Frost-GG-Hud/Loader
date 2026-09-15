-- Section/label rows inside a tab page.
--
-- The old AddLabel used a fixed 18px height, so any label longer than the tab
-- width was silently cut off. Text height is measured instead and the row grows.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TextService = game:GetService("TextService")

local TEXT_SIZE = 12
local MIN_HEIGHT = 18
local HORIZONTAL_MARGIN = 16
local GAP = 6

local function measureHeight(text, availableWidth)
	local ok, measured = pcall(function()
		return TextService:GetTextSize(
			text,
			TEXT_SIZE,
			Theme.FontRegular,
			Vector2.new(math.max(availableWidth, 1), math.huge)
		)
	end)
	if ok and measured then
		return math.max(MIN_HEIGHT, measured.Y + 2)
	end
	return MIN_HEIGHT
end

return function(tab, text, dim)
	local content = tostring(text or "")
	local width = tab:contentWidth()
	local height = measureHeight(content, width - HORIZONTAL_MARGIN)
	local y = tab:nextSlot(height, GAP)

	local lbl = Builder.label({
		Size = UDim2.new(1, -HORIZONTAL_MARGIN, 0, height),
		Position = UDim2.fromOffset(12, y),
		Font = Theme.FontRegular,
		TextSize = TEXT_SIZE,
		Text = content,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = dim and Theme.TextDim or Theme.TextMain,
		Parent = tab._page,
	})

	if tab.registerWidget then
		tab:registerWidget(lbl, height, GAP, content)
	end

	return lbl
end
