-- Text input row.
-- Used for entering custom values like Discord Webhook URLs or filter strings.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local HEIGHT = 56
local GAP = 8

return function(tab, labelText, placeholderText, defaultText, onCommit)
	local y = tab:nextSlot(HEIGHT, GAP)
	local currentText = tostring(defaultText or "")

	local card = Builder.frame({
		Name = "TextInputRow",
		Size = UDim2.new(1, -12, 0, HEIGHT),
		Position = UDim2.fromOffset(6, y),
		BackgroundColor3 = Theme.Card,
		Parent = tab._page,
	})
	Builder.corner(card, Theme.Metrics.CornerCard)

	Builder.label({
		Name = "Title",
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(12, 6),
		Font = Theme.FontMedium,
		TextSize = 12,
		Text = tostring(labelText),
		TextColor3 = Theme.TextMain,
		Parent = card,
	})

	local box = Builder.new("TextBox", {
		Name = "Input",
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 26),
		BackgroundColor3 = Theme.SurfaceAlt,
		BorderSizePixel = 0,
		Font = Theme.FontRegular,
		TextSize = 12,
		Text = currentText,
		PlaceholderText = tostring(placeholderText or "Paste URL here..."),
		PlaceholderColor3 = Theme.TextMuted,
		TextColor3 = tab._accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		Parent = card,
	})
	Builder.corner(box, Theme.Metrics.CornerSmall)
	Builder.padding(box, {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	local boxStroke = Builder.stroke(box, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.5,
	})

	box.Focused:Connect(function()
		boxStroke.Color = tab._accent
		boxStroke.Transparency = 0.2
	end)

	box.FocusLost:Connect(function(enterPressed)
		boxStroke.Color = Theme.Border
		boxStroke.Transparency = 0.5
		currentText = box.Text
		if onCommit then
			local ok, err = pcall(onCommit, currentText, enterPressed)
			if not ok then
				tab:_notify("Error: " .. tostring(err), "error")
			end
		end
	end)

	if tab.registerWidget then
		tab:registerWidget(card, HEIGHT, GAP, labelText)
	end

	return {
		Get = function()
			return box.Text
		end,
		Set = function(val)
			box.Text = tostring(val or "")
			currentText = box.Text
		end,
		_card = card,
		_box = box,
	}
end
