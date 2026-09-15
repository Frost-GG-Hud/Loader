-- On/off row.
--
-- Layout fix: the old label was sized `1, -54`, exactly up to where the switch
-- begins, so a longer label slid underneath the switch. The label now stops
-- short of the switch track and truncates cleanly instead of overlapping it.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TweenService = game:GetService("TweenService")

local SWITCH = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HEIGHT = 40
local GAP = 8
local TRACK_WIDTH = 42
local TRACK_HEIGHT = 20
local KNOB_SIZE = 14
local KNOB_INSET = 3
local TRACK_RIGHT_OFFSET = 14

local function knobPosition(on)
	local x = on and (TRACK_WIDTH - KNOB_INSET - KNOB_SIZE) or KNOB_INSET
	return UDim2.fromOffset(x, KNOB_INSET)
end

return function(tab, text, default, onChange)
	local accent = tab._accent
	local y = tab:nextSlot(HEIGHT, GAP)
	local value = default == true

	local card = Builder.frame({
		Name = "ToggleRow",
		Size = UDim2.new(1, -12, 0, HEIGHT),
		Position = UDim2.fromOffset(6, y),
		BackgroundColor3 = Theme.Card,
		Parent = tab._page,
	})
	Builder.corner(card, Theme.Metrics.CornerCard)

	Builder.label({
		Size = UDim2.new(1, -(TRACK_WIDTH + TRACK_RIGHT_OFFSET + 24), 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Font = Theme.FontRegular,
		TextSize = 13,
		Text = tostring(text),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme.TextMain,
		Parent = card,
	})

	local track = Builder.frame({
		Name = "Switch",
		Size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT),
		Position = UDim2.new(1, -(TRACK_WIDTH + TRACK_RIGHT_OFFSET), 0.5, -TRACK_HEIGHT / 2),
		BackgroundColor3 = Theme.Background,
		Parent = card,
	})
	Builder.pillCorner(track)

	local knob = Builder.frame({
		Name = "Knob",
		Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
		Position = knobPosition(value),
		BackgroundColor3 = Theme.TextDim,
		Parent = track,
	})
	Builder.pillCorner(knob)

	local function apply()
		TweenService:Create(track, SWITCH, {
			BackgroundColor3 = value and accent or Theme.Background,
		}):Play()
		TweenService:Create(knob, SWITCH, {
			Position = knobPosition(value),
			BackgroundColor3 = value and Theme.White or Theme.TextDim,
		}):Play()
	end

	local widget

	local function setValue(next, silent)
		value = next == true
		apply()
		if not silent and onChange then
			local ok, err = pcall(onChange, value)
			if not ok then
				tab:_notify("Error: " .. tostring(err), "error")
			end
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

	widget = {
		Get = function()
			return value
		end,
		Set = function(next, silent)
			setValue(next, silent)
		end,
		Toggle = function()
			setValue(not value)
		end,
		_card = card,
	}

	return widget
end
