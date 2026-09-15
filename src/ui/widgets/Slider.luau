-- Range row.
--
-- The old slider attached its drag handler to an invisible 18x18 button placed
-- at the card's bottom-LEFT corner, while the visible track started 12px in and
-- was 4px tall. The grab handle did not line up with the track, the knob was
-- invisible, and clicking the track did nothing at all.
--
-- Here the whole track band is a click/drag target, the knob sits on the track
-- and follows the value, and clicking anywhere on the track jumps to that value
-- like a real slider.

local ctx = ...
local Util = ctx.require("core/Util")
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local UserInputService = game:GetService("UserInputService")

local HEIGHT = 48
local GAP = 8
local TRACK_HEIGHT = 4
local KNOB_SIZE = 14
local TRACK_X = 12
local TRACK_BOTTOM = 14
local HIT_HEIGHT = 18

return function(tab, text, min, max, default, onChange, step)
	min = tonumber(min) or 0
	max = tonumber(max) or 100
	if max <= min then
		max = min + 1
	end
	step = tonumber(step) or 1

	local accent = tab._accent
	local y = tab:nextSlot(HEIGHT, GAP)
	local value = math.clamp(tonumber(default) or min, min, max)

	local card = Builder.frame({
		Name = "SliderRow",
		Size = UDim2.new(1, -12, 0, HEIGHT),
		Position = UDim2.fromOffset(6, y),
		BackgroundColor3 = Theme.Card,
		Parent = tab._page,
	})
	Builder.corner(card, Theme.Metrics.CornerCard)

	Builder.label({
		Size = UDim2.new(1, -80, 0, 18),
		Position = UDim2.fromOffset(12, 5),
		Font = Theme.FontRegular,
		TextSize = 12,
		Text = tostring(text),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme.TextMain,
		Parent = card,
	})

	local valueChip = Builder.new("TextBox", {
		Size = UDim2.fromOffset(52, 22),
		Position = UDim2.new(1, -62, 0, 4),
		BackgroundColor3 = Theme.SurfaceAlt,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Theme.FontBold,
		TextSize = 12,
		Text = tostring(value),
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		Parent = card,
	})
	Builder.corner(valueChip, Theme.Metrics.CornerSmall)
	Builder.stroke(valueChip, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.5,
	})

	local track = Builder.frame({
		Name = "Track",
		Size = UDim2.new(1, -(TRACK_X * 2), 0, TRACK_HEIGHT),
		Position = UDim2.new(0, TRACK_X, 1, -TRACK_BOTTOM),
		BackgroundColor3 = Theme.Background,
		Parent = card,
	})
	Builder.pillCorner(track)

	local fill = Builder.frame({
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = accent,
		Parent = track,
	})
	Builder.pillCorner(fill)

	local knob = Builder.frame({
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
		BackgroundColor3 = accent,
		Parent = track,
	})
	Builder.pillCorner(knob)
	Builder.stroke(knob, {
		Color = Theme.Window,
		Thickness = 2,
		Transparency = 0,
	})

	local function fractionOf(current)
		return math.clamp((current - min) / (max - min), 0, 1)
	end

	local function snap(raw)
		local snapped = min + math.round((raw - min) / step) * step
		return math.clamp(snapped, min, max)
	end

	local function render(current)
		local fraction = fractionOf(current)
		fill.Size = UDim2.fromScale(fraction, 1)
		knob.Position = UDim2.new(fraction, 0, 0.5, 0)
		valueChip.Text = tostring(current)
	end

	local function commit(current, silent)
		current = snap(current)
		if current == value then
			render(value)
			return
		end
		value = current
		render(value)
		if not silent and onChange then
			local ok, err = pcall(onChange, value)
			if not ok then
				tab:_notify("Error: " .. tostring(err), "error")
			end
		end
	end

	local function valueFromScreenX(screenX)
		local originX = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		local fraction = math.clamp((screenX - originX) / width, 0, 1)
		return min + (max - min) * fraction
	end

	local moveConnection = nil
	local releaseConnection = nil

	local function stopTracking()
		if moveConnection then
			moveConnection:Disconnect()
			moveConnection = nil
		end
		if releaseConnection then
			releaseConnection:Disconnect()
			releaseConnection = nil
		end
	end
	tab:_trackCleanup(stopTracking)

	local hit = Builder.button({
		Name = "Hit",
		Size = UDim2.new(1, -(TRACK_X * 2), 0, HIT_HEIGHT),
		Position = UDim2.new(0, TRACK_X, 1, -(TRACK_BOTTOM + HIT_HEIGHT / 2 + TRACK_HEIGHT / 2)),
		Parent = card,
	})

	hit.InputBegan:Connect(function(input)
		if not Util.isDragInput(input.UserInputType) then
			return
		end

		stopTracking()
		-- Jump straight to where the user pressed, then keep following the drag.
		commit(valueFromScreenX(input.Position.X))

		moveConnection = UserInputService.InputChanged:Connect(function(move)
			if move.UserInputType == Enum.UserInputType.MouseMovement
				or (move.UserInputType == Enum.UserInputType.Touch and move == input)
			then
				commit(valueFromScreenX(move.Position.X))
			end
		end)

		releaseConnection = UserInputService.InputEnded:Connect(function(release)
			if Util.isDragInput(release.UserInputType) then
				stopTracking()
			end
		end)
	end)

	valueChip.FocusLost:Connect(function()
		local typed = tonumber(valueChip.Text)
		if typed then
			commit(typed)
		else
			render(value)
		end
	end)

	render(value)

	if tab.registerWidget then
		tab:registerWidget(card, HEIGHT, GAP, text)
	end

	return {
		Get = function()
			return value
		end,
		Set = function(next, silent)
			commit(next, silent)
		end,
		_card = card,
	}
end
