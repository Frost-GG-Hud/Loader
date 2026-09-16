-- Keybind widget (Fluent / Rayfield style).
-- Allows users to rebind a feature toggle/action to any keyboard key dynamically.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local HEIGHT = 40
local GAP = 8
local ANIM = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function keyName(key)
	if not key then
		return "None"
	end
	return (string.gsub(tostring(key), "^Enum%.KeyCode%.", ""))
end

return function(tab, labelText, defaultKey, onKeyChanged, onTrigger)
	local accent = tab._accent
	local y = tab:nextSlot(HEIGHT, GAP)
	local currentKey = defaultKey
	local isListening = false

	local card = Builder.frame({
		Name = "KeybindRow",
		Size = UDim2.new(1, -12, 0, HEIGHT),
		Position = UDim2.fromOffset(6, y),
		BackgroundColor3 = Theme.Card,
		Parent = tab._page,
	})
	Builder.corner(card, Theme.Metrics.CornerCard)
	local cardStroke = Builder.stroke(card, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.45,
	})

	Builder.label({
		Name = "Title",
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Font = Theme.FontMedium,
		TextSize = 12,
		Text = tostring(labelText),
		TextColor3 = Theme.TextMain,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})

	local bindPill = Builder.button({
		Name = "BindPill",
		Size = UDim2.new(0, 94, 0, 26),
		Position = UDim2.new(1, -106, 0.5, -13),
		BackgroundColor3 = Theme.SurfaceAlt,
		Parent = card,
	})
	Builder.corner(bindPill, 6)
	local pillStroke = Builder.stroke(bindPill, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.35,
	})

	local bindLabel = Builder.label({
		Name = "BindLabel",
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.FontBold,
		TextSize = 11,
		Text = "[ " .. keyName(currentKey) .. " ]",
		TextColor3 = currentKey and accent or Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = bindPill,
	})

	local inputConnection = nil

	local function stopListening()
		isListening = false
		bindLabel.Text = "[ " .. keyName(currentKey) .. " ]"
		bindLabel.TextColor3 = currentKey and accent or Theme.TextDim
		TweenService:Create(pillStroke, ANIM, { Color = Theme.Border }):Play()
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
	end

	local function startListening()
		if isListening then
			stopListening()
			return
		end

		isListening = true
		bindLabel.Text = "[ ... ]"
		bindLabel.TextColor3 = Theme.Warning
		TweenService:Create(pillStroke, ANIM, { Color = Theme.BorderActive }):Play()

		inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
			if not isListening then
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local code = input.KeyCode
				if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then
					currentKey = nil
				else
					currentKey = code
				end
				stopListening()
				if onKeyChanged then
					pcall(onKeyChanged, currentKey)
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3
			then
				-- ignore the click on the pill itself
			end
		end)
	end

	bindPill.MouseButton1Click:Connect(startListening)

	-- Global trigger listener
	local triggerConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or isListening then
			return
		end
		if not currentKey then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == currentKey then
			if onTrigger then
				pcall(onTrigger, currentKey)
			end
		end
	end)

	if tab._trackCleanup then
		tab:_trackCleanup(function()
			if triggerConn then
				triggerConn:Disconnect()
				triggerConn = nil
			end
			if inputConnection then
				inputConnection:Disconnect()
				inputConnection = nil
			end
		end)
	end

	if tab.registerWidget then
		tab:registerWidget(card, HEIGHT, GAP, labelText)
	end

	return {
		Get = function()
			return currentKey
		end,
		Set = function(key)
			currentKey = key
			bindLabel.Text = "[ " .. keyName(currentKey) .. " ]"
			bindLabel.TextColor3 = currentKey and accent or Theme.TextDim
			if onKeyChanged then
				pcall(onKeyChanged, currentKey)
			end
		end,
		_card = card,
	}
end
