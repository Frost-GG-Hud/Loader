-- 2-Column Grid Row widget (Zeroin UI style).
-- Displays two feature cards side-by-side with subtitles and toggle switches or input boxes.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")
local TweenService = game:GetService("TweenService")

local SWITCH_ANIM = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ROW_HEIGHT = 50
local ROW_GAP = 7

local TRACK_WIDTH = 38
local TRACK_HEIGHT = 18
local KNOB_SIZE = 12
local KNOB_INSET = 3

local function knobPosition(on)
	local x = on and (TRACK_WIDTH - KNOB_INSET - KNOB_SIZE) or KNOB_INSET
	return UDim2.fromOffset(x, KNOB_INSET)
end

local GridRow = {}

-- Creates a 2-column dual toggle row
function GridRow.dualToggle(tab, leftOpts, rightOpts)
	local y = tab:nextSlot(ROW_HEIGHT, ROW_GAP)
	local accent = tab._accent

	local function buildToggleCard(opts, isRight)
		if not opts then return nil end
		local xPos = isRight and UDim2.new(0.5, 3, 0, y) or UDim2.new(0, 6, 0, y)
		local width = UDim2.new(0.5, -9, 0, ROW_HEIGHT)

		local card = Builder.frame({
			Name = "GridToggleCard",
			Size = width,
			Position = xPos,
			BackgroundColor3 = Theme.Card,
			Parent = tab._page,
		})
		Builder.corner(card, Theme.Metrics.CornerCard)
		Builder.stroke(card, {
			Color = Theme.Border,
			Thickness = 1,
			Transparency = 0.45,
		})

		Builder.label({
			Name = "Title",
			Size = UDim2.new(1, -(TRACK_WIDTH + 20), 0, 16),
			Position = UDim2.fromOffset(10, 8),
			Font = Theme.FontBold,
			TextSize = 12,
			Text = tostring(opts.title or ""),
			TextColor3 = Theme.TextMain,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})

		Builder.label({
			Name = "Subtitle",
			Size = UDim2.new(1, -(TRACK_WIDTH + 20), 0, 14),
			Position = UDim2.fromOffset(10, 26),
			Font = Theme.FontRegular,
			TextSize = 9,
			Text = tostring(opts.desc or ""),
			TextColor3 = Theme.TextMuted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})

		local track = Builder.frame({
			Name = "Track",
			Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT),
			Position = UDim2.new(1, -(TRACK_WIDTH + 10), 0.5, -TRACK_HEIGHT / 2),
			BackgroundColor3 = Theme.SurfaceAlt,
			Parent = card,
		})
		Builder.pillCorner(track)

		local knob = Builder.frame({
			Name = "Knob",
			Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
			Position = knobPosition(opts.default == true),
			BackgroundColor3 = opts.default == true and Theme.White or Theme.TextDim,
			Parent = track,
		})
		Builder.pillCorner(knob)

		local value = opts.default == true

		local function apply()
			TweenService:Create(track, SWITCH_ANIM, {
				BackgroundColor3 = value and accent or Theme.SurfaceAlt,
			}):Play()
			TweenService:Create(knob, SWITCH_ANIM, {
				Position = knobPosition(value),
				BackgroundColor3 = value and Theme.White or Theme.TextDim,
			}):Play()
		end

		local function setValue(nextVal, silent)
			value = nextVal == true
			apply()
			if not silent and opts.onChange then
				pcall(opts.onChange, value)
			end
		end

		local hit = Builder.button({
			Name = "Hit",
			Size = UDim2.new(1, 0, 1, 0),
			Parent = card,
		})
		hit.MouseButton1Click:Connect(function()
			setValue(not value)
		end)

		apply()

		return {
			Get = function() return value end,
			Set = function(v, s) setValue(v, s) end,
			_card = card,
		}
	end

	local left = buildToggleCard(leftOpts, false)
	local right = buildToggleCard(rightOpts, true)
	return { left = left, right = right }
end

-- Creates a 2-column dual input row (e.g. Speed on left, Steal By Value on right)
function GridRow.dualInput(tab, leftOpts, rightOpts)
	local y = tab:nextSlot(ROW_HEIGHT + 8, ROW_GAP)

	local function buildInputCard(opts, isRight)
		if not opts then return nil end
		local xPos = isRight and UDim2.new(0.5, 3, 0, y) or UDim2.new(0, 6, 0, y)
		local width = UDim2.new(0.5, -9, 0, ROW_HEIGHT + 8)

		local card = Builder.frame({
			Name = "GridInputCard",
			Size = width,
			Position = xPos,
			BackgroundColor3 = Theme.Card,
			Parent = tab._page,
		})
		Builder.corner(card, Theme.Metrics.CornerCard)
		Builder.stroke(card, {
			Color = Theme.Border,
			Thickness = 1,
			Transparency = 0.45,
		})

		Builder.label({
			Name = "Title",
			Size = UDim2.new(1, -16, 0, 16),
			Position = UDim2.fromOffset(10, 6),
			Font = Theme.FontBold,
			TextSize = 12,
			Text = tostring(opts.title or ""),
			TextColor3 = Theme.TextMain,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})

		Builder.label({
			Name = "Subtitle",
			Size = UDim2.new(1, -16, 0, 12),
			Position = UDim2.fromOffset(10, 22),
			Font = Theme.FontRegular,
			TextSize = 9,
			Text = tostring(opts.desc or ""),
			TextColor3 = Theme.TextMuted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})

		local box = Builder.new("TextBox", {
			Name = "Input",
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(10, 36),
			BackgroundColor3 = Theme.SurfaceAlt,
			BorderSizePixel = 0,
			Font = Theme.FontBold,
			TextSize = 11,
			Text = tostring(opts.default or ""),
			PlaceholderText = tostring(opts.placeholder or ""),
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

		box.FocusLost:Connect(function(enterPressed)
			if opts.onChange then
				pcall(opts.onChange, box.Text, enterPressed)
			end
		end)

		return {
			Get = function() return box.Text end,
			Set = function(t) box.Text = tostring(t or "") end,
			_card = card,
		}
	end

	local left = buildInputCard(leftOpts, false)
	local right = buildInputCard(rightOpts, true)
	return { left = left, right = right }
end

return function(tab)
	function tab:AddToggleGrid(leftOpts, rightOpts)
		return GridRow.dualToggle(self, leftOpts, rightOpts)
	end
	function tab:AddInputGrid(leftOpts, rightOpts)
		return GridRow.dualInput(self, leftOpts, rightOpts)
	end
	return tab
end
