-- Dropdown selection widget (Fluent / Rayfield style).
-- Supports single-selection or multi-selection with smooth expanding container and dynamic option lists.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TweenService = game:GetService("TweenService")

local COLLAPSED_HEIGHT = 44
local OPTION_HEIGHT = 26
local MAX_EXPANDED_HEIGHT = 200
local GAP = 8
local ANIM_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

return function(tab, labelText, options, defaultSelected, onSelect, isMulti)
	local accent = tab._accent
	local y = tab:nextSlot(COLLAPSED_HEIGHT, GAP)

	options = options or {}
	isMulti = isMulti == true

	local selected = {}
	if isMulti then
		if type(defaultSelected) == "table" then
			for _, v in ipairs(defaultSelected) do
				selected[v] = true
			end
		end
	else
		selected = defaultSelected or options[1] or ""
	end

	local isOpen = false
	local currentHeight = COLLAPSED_HEIGHT

	local card = Builder.frame({
		Name = "DropdownRow",
		Size = UDim2.new(1, -12, 0, COLLAPSED_HEIGHT),
		Position = UDim2.fromOffset(6, y),
		BackgroundColor3 = Theme.Card,
		ClipsDescendants = true,
		Parent = tab._page,
	})
	Builder.corner(card, Theme.Metrics.CornerCard)
	local cardStroke = Builder.stroke(card, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.45,
	})

	local topBar = Builder.button({
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, COLLAPSED_HEIGHT),
		Position = UDim2.fromOffset(0, 0),
		Parent = card,
	})

	Builder.label({
		Name = "Title",
		Size = UDim2.new(0.5, -16, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Font = Theme.FontMedium,
		TextSize = 12,
		Text = tostring(labelText),
		TextColor3 = Theme.TextMain,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = topBar,
	})

	local selectPill = Builder.frame({
		Name = "SelectPill",
		Size = UDim2.new(0.5, -12, 0, 26),
		Position = UDim2.new(0.5, 0, 0.5, -13),
		BackgroundColor3 = Theme.SurfaceAlt,
		Parent = topBar,
	})
	Builder.corner(selectPill, 6)
	Builder.stroke(selectPill, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.5,
	})

	local displayLabel = Builder.label({
		Name = "Display",
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Font = Theme.FontRegular,
		TextSize = 11,
		TextColor3 = accent,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = selectPill,
	})

	local arrowLabel = Builder.label({
		Name = "Arrow",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -22, 0.5, -9),
		Font = Theme.FontBold,
		TextSize = 10,
		Text = "▼",
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = selectPill,
	})

	-- Options list container
	local listFrame = Builder.new("ScrollingFrame", {
		Name = "OptionsList",
		Size = UDim2.new(1, -24, 0, 0),
		Position = UDim2.fromOffset(12, COLLAPSED_HEIGHT + 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.BorderActive,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Visible = false,
		Parent = card,
	})

	local listLayout = Builder.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		Parent = listFrame,
	})

	local function getDisplayText()
		if isMulti then
			local count = 0
			for _ in pairs(selected) do
				count = count + 1
			end
			if count == 0 then
				return "None selected"
			elseif count == 1 then
				local item = next(selected)
				return tostring(item)
			else
				return count .. " selected"
			end
		else
			return tostring(selected == "" and "Choose..." or selected)
		end
	end

	local function updateDisplay()
		displayLabel.Text = getDisplayText()
	end

	local function calcExpandedHeight()
		local totalOptionsHeight = #options * (OPTION_HEIGHT + 3) + 8
		return math.clamp(COLLAPSED_HEIGHT + totalOptionsHeight + 6, COLLAPSED_HEIGHT, MAX_EXPANDED_HEIGHT)
	end

	local toggleOpen = nil

	local function renderOptions()
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end

		for idx, opt in ipairs(options) do
			local optName = tostring(opt)
			local isCurrent = false
			if isMulti then
				isCurrent = selected[optName] == true
			else
				isCurrent = selected == optName
			end

			local optBtn = Builder.button({
				Name = "Option_" .. optName,
				Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
				BackgroundColor3 = isCurrent and Theme.SurfaceAlt or Theme.Surface,
				BackgroundTransparency = isCurrent and 0 or 0.5,
				LayoutOrder = idx,
				Parent = listFrame,
			})
			Builder.corner(optBtn, 5)

			local checkIndicator = Builder.label({
				Name = "Check",
				Size = UDim2.fromOffset(16, OPTION_HEIGHT),
				Position = UDim2.fromOffset(6, 0),
				Font = Theme.FontBold,
				TextSize = 11,
				Text = isCurrent and "✓" or "",
				TextColor3 = accent,
				Parent = optBtn,
			})

			local optLabel = Builder.label({
				Name = "Label",
				Size = UDim2.new(1, -28, 1, 0),
				Position = UDim2.fromOffset(24, 0),
				Font = isCurrent and Theme.FontMedium or Theme.FontRegular,
				TextSize = 11,
				Text = optName,
				TextColor3 = isCurrent and Theme.TextMain or Theme.TextDim,
				Parent = optBtn,
			})

			optBtn.MouseEnter:Connect(function()
				TweenService:Create(optBtn, ANIM_INFO, { BackgroundTransparency = 0.2 }):Play()
			end)

			optBtn.MouseLeave:Connect(function()
				local active = isMulti and (selected[optName] == true) or (selected == optName)
				TweenService:Create(optBtn, ANIM_INFO, { BackgroundTransparency = active and 0 or 0.5 }):Play()
			end)

			optBtn.MouseButton1Click:Connect(function()
				if isMulti then
					if selected[optName] then
						selected[optName] = nil
					else
						selected[optName] = true
					end
					updateDisplay()
					renderOptions()
					if onSelect then
						local arr = {}
						for k in pairs(selected) do
							table.insert(arr, k)
						end
						pcall(onSelect, arr, optName)
					end
				else
					selected = optName
					updateDisplay()
					renderOptions()
					-- Collapse on single selection
					if isOpen and toggleOpen then
						toggleOpen()
					end
					if onSelect then
						pcall(onSelect, selected)
					end
				end
			end)
		end

		local contentH = #options * (OPTION_HEIGHT + 3)
		listFrame.CanvasSize = UDim2.new(0, 0, 0, contentH)
	end

	toggleOpen = function()
		isOpen = not isOpen
		arrowLabel.Text = isOpen and "▲" or "▼"
		arrowLabel.TextColor3 = isOpen and accent or Theme.TextDim
		cardStroke.Color = isOpen and Theme.BorderActive or Theme.Border

		local targetH = isOpen and calcExpandedHeight() or COLLAPSED_HEIGHT
		currentHeight = targetH

		if isOpen then
			listFrame.Visible = true
			listFrame.Size = UDim2.new(1, -24, 0, targetH - COLLAPSED_HEIGHT - 10)
		end

		local tween = TweenService:Create(card, ANIM_INFO, {
			Size = UDim2.new(1, -12, 0, targetH),
		})
		tween:Play()

		if not isOpen then
			tween.Completed:Connect(function()
				if not isOpen then
					listFrame.Visible = false
				end
			end)
		end

		if tab.relayout then
			tab:relayout()
		end
	end

	topBar.MouseButton1Click:Connect(toggleOpen)

	renderOptions()
	updateDisplay()

	if tab.registerWidget then
		tab:registerWidget(card, COLLAPSED_HEIGHT, GAP, labelText, function()
			return currentHeight
		end)
	end

	local widget = {
		Get = function()
			if isMulti then
				local arr = {}
				for k in pairs(selected) do
					table.insert(arr, k)
				end
				return arr
			else
				return selected
			end
		end,
		Set = function(val, silent)
			if isMulti and type(val) == "table" then
				selected = {}
				for _, v in ipairs(val) do
					selected[v] = true
				end
			else
				selected = tostring(val or "")
			end
			updateDisplay()
			renderOptions()
			if not silent and onSelect then
				pcall(onSelect, widget.Get())
			end
		end,
		SetOptions = function(newOptions)
			options = newOptions or {}
			renderOptions()
			updateDisplay()
			if isOpen then
				currentHeight = calcExpandedHeight()
				card.Size = UDim2.new(1, -12, 0, currentHeight)
				listFrame.Size = UDim2.new(1, -24, 0, currentHeight - COLLAPSED_HEIGHT - 10)
				if tab.relayout then
					tab:relayout()
				end
			end
		end,
		_card = card,
	}

	return widget
end
