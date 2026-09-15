-- Section title and divider line.
-- Groups related widgets inside a tab with visual clarity.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local HEIGHT = 24
local GAP = 12

return function(tab, title)
	local y = tab:nextSlot(HEIGHT, GAP)

	local row = Builder.frame({
		Name = "SectionRow",
		Size = UDim2.new(1, -12, 0, HEIGHT),
		Position = UDim2.fromOffset(6, y),
		BackgroundTransparency = 1,
		Parent = tab._page,
	})

	local titleLabel = Builder.label({
		Name = "SectionTitle",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(4, 0),
		Font = Theme.FontBold,
		TextSize = 11,
		Text = string.upper(tostring(title)),
		TextColor3 = tab._accent,
		ZIndex = 3,
		Parent = row,
	})

	local line = Builder.frame({
		Name = "Divider",
		Size = UDim2.new(1, -10, 0, 1),
		Position = UDim2.new(0, 8, 1, -2),
		BackgroundColor3 = Theme.Border,
		BackgroundTransparency = 0.5,
		ZIndex = 2,
		Parent = row,
	})
	Builder.corner(line, 1)

	return { _row = row, _title = titleLabel }
end
