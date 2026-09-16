-- Egg Predictor Tab (Ajjans Steal an Egg V4.6 style)
-- Matches reference screenshot:
--  * Section Header: Egg Predictor
--  * Controls: Sort By dropdown & Preview Card toggle
--  * Search Eggs input
--  * Large Hero Preview Card with framed thumbnail, Pet Name [RARITY], Rate/s, Multiplier & Weight, Status
--  * Live summary counter: "X eggs • Y ready • Z growing • W in bag • Total +XX.XXM/s"
--  * Grouped cards: "READY TO HATCH" (green border) & "IN INVENTORY" (dark red border)

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")
local EggData = ctx.require("features/StealAnEgg/EggData")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local RARITY_ORDER = {
	Secret = 10,
	Divine = 9,
	Cosmic = 8,
	Mythic = 7,
	Legendary = 6,
	Epic = 5,
	Rare = 4,
	Uncommon = 3,
	Common = 2,
}

local function getRarityRank(rarity)
	return RARITY_ORDER[rarity] or 1
end

local function formatWeight(kg)
	if not kg or kg <= 0 then
		return "100Kg"
	end
	if kg >= 1000 then
		return string.format("%d,%03dKg", math.floor(kg / 1000), math.floor(kg % 1000))
	end
	return string.format("%dKg", math.floor(kg))
end

local function formatNumberShort(num)
	if not num or num <= 0 then
		return "0"
	end
	if num >= 1e9 then
		return string.format("+%.2fB/s", num / 1e9)
	elseif num >= 1e6 then
		return string.format("+%.2fM/s", num / 1e6)
	elseif num >= 1e3 then
		return string.format("+%.1fK/s", num / 1e3)
	end
	return string.format("+%.0f/s", num)
end

return function(tab, cleanup)
	local page = tab._page
	local activeFilter = ""
	local sortBy = "Rarity"
	local showPreviewCard = true
	local selectedEgg = nil

	-- 1. Section Header: Egg Predictor
	local headerY = tab:nextSlot(28, 4)
	local headerFrame = Builder.frame({
		Name = "SectionHeader",
		Size = UDim2.new(1, -12, 0, 28),
		Position = UDim2.fromOffset(6, headerY),
		BackgroundTransparency = 1,
		Parent = page,
	})

	local eggIcon = Builder.label({
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(2, 2),
		Font = Theme.FontBold,
		TextSize = 16,
		Text = "🥚",
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = headerFrame,
	})

	local titleLbl = Builder.label({
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(30, 0),
		Font = Theme.FontBold,
		TextSize = 14,
		Text = "Egg Predictor",
		TextColor3 = Theme.TextMain,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = headerFrame,
	})

	local chevronLbl = Builder.label({
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -26, 0, 2),
		Font = Theme.FontBold,
		TextSize = 13,
		Text = "v",
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = headerFrame,
	})

	-- 2. Controls: Sort By Dropdown & Preview Card Toggle
	local ctrlY = tab:nextSlot(44, 4)
	local ctrlFrame = Builder.frame({
		Name = "ControlsFrame",
		Size = UDim2.new(1, -12, 0, 44),
		Position = UDim2.fromOffset(6, ctrlY),
		BackgroundTransparency = 1,
		Parent = page,
	})

	-- Sort By
	Builder.label({
		Size = UDim2.new(0, 100, 0, 14),
		Position = UDim2.fromOffset(4, 0),
		Font = Theme.FontMedium,
		TextSize = 10,
		Text = "Sort By",
		TextColor3 = Theme.TextDim,
		Parent = ctrlFrame,
	})

	local sortBtn = Builder.button({
		Name = "SortDropdown",
		Size = UDim2.new(0.65, -8, 0, 24),
		Position = UDim2.fromOffset(4, 18),
		BackgroundColor3 = Theme.Card,
		Parent = ctrlFrame,
	})
	Builder.corner(sortBtn, 6)
	Builder.stroke(sortBtn, { Color = Theme.Border, Thickness = 1, Transparency = 0.4 })

	local sortLabel = Builder.label({
		Size = UDim2.new(1, -26, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		Font = Theme.FontMedium,
		TextSize = 10,
		Text = "Rarity",
		TextColor3 = Theme.TextMain,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sortBtn,
	})

	Builder.label({
		Size = UDim2.fromOffset(20, 24),
		Position = UDim2.new(1, -22, 0, 0),
		Font = Theme.FontBold,
		TextSize = 10,
		Text = "v",
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = sortBtn,
	})

	local sortModes = { "Rarity", "Value / sec", "Weight", "Status" }
	local sortIndex = 1
	sortBtn.MouseButton1Click:Connect(function()
		sortIndex = (sortIndex % #sortModes) + 1
		sortBy = sortModes[sortIndex]
		sortLabel.Text = sortBy
		-- trigger refresh
		if tab._refreshEggs then
			tab._refreshEggs()
		end
	end)

	-- Preview Card Toggle
	local toggleContainer = Builder.frame({
		Name = "ToggleContainer",
		Size = UDim2.new(0.35, 0, 1, 0),
		Position = UDim2.new(0.65, 4, 0, 0),
		BackgroundTransparency = 1,
		Parent = ctrlFrame,
	})

	Builder.label({
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 0),
		Font = Theme.FontMedium,
		TextSize = 10,
		Text = "Preview Card",
		TextColor3 = Theme.TextDim,
		Parent = toggleContainer,
	})

	local togglePill = Builder.button({
		Name = "ToggleSwitch",
		Size = UDim2.fromOffset(40, 20),
		Position = UDim2.new(1, -44, 0, 18),
		BackgroundColor3 = Theme.Accent,
		Parent = toggleContainer,
	})
	Builder.pillCorner(togglePill)

	local toggleKnob = Builder.frame({
		Name = "Knob",
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(23, 3),
		BackgroundColor3 = Theme.White,
		Parent = togglePill,
	})
	Builder.pillCorner(toggleKnob)

	-- 3. Search Eggs Bar
	local searchY = tab:nextSlot(46, 6)
	local searchFrame = Builder.frame({
		Name = "SearchSection",
		Size = UDim2.new(1, -12, 0, 46),
		Position = UDim2.fromOffset(6, searchY),
		BackgroundTransparency = 1,
		Parent = page,
	})

	Builder.label({
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(4, 0),
		Font = Theme.FontMedium,
		TextSize = 10,
		Text = "Search Eggs",
		TextColor3 = Theme.TextDim,
		Parent = searchFrame,
	})

	local searchBox = Builder.frame({
		Name = "SearchBox",
		Size = UDim2.new(1, -8, 0, 26),
		Position = UDim2.fromOffset(4, 18),
		BackgroundColor3 = Theme.Card,
		Parent = searchFrame,
	})
	Builder.corner(searchBox, 6)
	local searchStroke = Builder.stroke(searchBox, { Color = Theme.Border, Thickness = 1, Transparency = 0.4 })

	local searchInput = Builder.new("TextBox", {
		Name = "Input",
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Font = Theme.FontRegular,
		TextSize = 10,
		Text = "",
		PlaceholderText = "Search by pet name, mutation, status...",
		PlaceholderColor3 = Theme.TextMuted,
		TextColor3 = Theme.TextMain,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 3,
		Parent = searchBox,
	})

	-- 4. Hero Preview Card
	local previewCardY = tab:nextSlot(92, 8)
	local heroCard = Builder.frame({
		Name = "HeroPreviewCard",
		Size = UDim2.new(1, -12, 0, 92),
		Position = UDim2.fromOffset(6, previewCardY),
		BackgroundColor3 = Theme.Card,
		Parent = page,
	})
	Builder.corner(heroCard, 8)
	Builder.stroke(heroCard, { Color = Theme.Border, Thickness = 1, Transparency = 0.3 })

	-- Left Thumbnail Box
	local thumbBox = Builder.frame({
		Name = "ThumbnailBox",
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Theme.Background,
		Parent = heroCard,
	})
	Builder.corner(thumbBox, 6)
	Builder.stroke(thumbBox, { Color = Theme.Border, Thickness = 1, Transparency = 0.4 })

	local thumbEggIcon = Builder.label({
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.FontBold,
		TextSize = 36,
		Text = "🥚",
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = thumbBox,
	})

	-- Right Details
	local heroPetName = Builder.label({
		Name = "PetName",
		Size = UDim2.new(1, -96, 0, 18),
		Position = UDim2.fromOffset(92, 10),
		Font = Theme.FontBold,
		TextSize = 12,
		Text = "Sabertooth Tiger [MYTHIC]",
		TextColor3 = Theme.Rarities.Mythic,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = heroCard,
	})

	local heroRate = Builder.label({
		Name = "Rate",
		Size = UDim2.new(1, -96, 0, 14),
		Position = UDim2.fromOffset(92, 28),
		Font = Theme.FontBold,
		TextSize = 11,
		Text = "+37.7K/s",
		TextColor3 = Theme.SpeedCyan,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = heroCard,
	})

	local heroStats = Builder.label({
		Name = "Stats",
		Size = UDim2.new(1, -96, 0, 14),
		Position = UDim2.fromOffset(92, 44),
		Font = Theme.FontRegular,
		TextSize = 10,
		Text = "1.04x • 395Kg",
		TextColor3 = Theme.WeightGold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = heroCard,
	})

	local heroStatus = Builder.label({
		Name = "Status",
		Size = UDim2.new(1, -96, 0, 14),
		Position = UDim2.fromOffset(92, 60),
		Font = Theme.FontMedium,
		TextSize = 10,
		Text = "Ready to hatch",
		TextColor3 = Theme.ReadyGreen,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = heroCard,
	})

	local heroSubtext = Builder.label({
		Name = "Subtext",
		Size = UDim2.new(1, -96, 0, 12),
		Position = UDim2.fromOffset(92, 74),
		Font = Theme.FontRegular,
		TextSize = 9,
		Text = "Tap an egg below to preview it",
		TextColor3 = Theme.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = heroCard,
	})

	-- Toggle Preview Card Click
	togglePill.MouseButton1Click:Connect(function()
		showPreviewCard = not showPreviewCard
		heroCard.Visible = showPreviewCard
		if showPreviewCard then
			togglePill.BackgroundColor3 = Theme.Accent
			toggleKnob.Position = UDim2.fromOffset(23, 3)
		else
			togglePill.BackgroundColor3 = Theme.SurfaceAlt
			toggleKnob.Position = UDim2.fromOffset(3, 3)
		end
	end)

	-- 5. Summary Status Bar
	local summaryY = tab:nextSlot(24, 6)
	local summaryLabel = Builder.label({
		Name = "SummaryLabel",
		Size = UDim2.new(1, -12, 0, 20),
		Position = UDim2.fromOffset(8, summaryY),
		Font = Theme.FontMedium,
		TextSize = 9,
		Text = "63 eggs • 1 ready • 0 growing • 62 in bag • Total +134.47M/s",
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = page,
	})

	-- Container for dynamic egg lists
	local listsContainer = Builder.frame({
		Name = "ListsContainer",
		Size = UDim2.new(1, -12, 0, 100),
		Position = UDim2.fromOffset(6, tab._y + 4),
		BackgroundTransparency = 1,
		Parent = page,
	})

	local function updateHeroCard(egg)
		selectedEgg = egg
		if not egg then
			return
		end
		heroPetName.Text = string.format("%s [%s]", egg.petName or "Unknown", string.upper(egg.rarity or "COMMON"))
		heroPetName.TextColor3 = Theme.getRarityColor(egg.rarity)
		heroRate.Text = egg.moneyText or formatNumberShort(egg.moneyPerSec)
		heroStats.Text = string.format("%.2fx • %s", egg.multiplier or 1.0, formatWeight(egg.weight or 395))
		heroStatus.Text = egg.status or (egg.ready and "Ready to hatch" or "In inventory")
		heroStatus.TextColor3 = egg.ready and Theme.ReadyGreen or Theme.Accent
	end

	-- Build Egg Card Component
	local function createEggCard(parent, egg, yOffset, isReady)
		local card = Builder.button({
			Name = "EggCard_" .. tostring(egg.uid or egg.petName),
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, yOffset),
			BackgroundColor3 = Theme.Card,
			Parent = parent,
		})
		Builder.corner(card, 6)
		local stroke = Builder.stroke(card, {
			Color = isReady and Theme.BorderReady or Theme.Border,
			Thickness = isReady and 1.5 or 1,
			Transparency = isReady and 0.1 or 0.5,
		})

		-- Thumbnail
		local cardThumb = Builder.frame({
			Size = UDim2.fromOffset(36, 36),
			Position = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Theme.Background,
			Parent = card,
		})
		Builder.corner(cardThumb, 4)

		Builder.label({
			Size = UDim2.new(1, 0, 1, 0),
			Font = Theme.FontBold,
			TextSize = 18,
			Text = "🥚",
			TextColor3 = isReady and Theme.ReadyGreen or Theme.Accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cardThumb,
		})

		-- Details
		local petTitle = Builder.label({
			Size = UDim2.new(1, -150, 0, 16),
			Position = UDim2.fromOffset(48, 6),
			Font = Theme.FontBold,
			TextSize = 11,
			Text = string.format("%s [%s]", egg.petName or "Pet", string.upper(egg.rarity or "COMMON")),
			TextColor3 = Theme.getRarityColor(egg.rarity),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		local statsLine = Builder.label({
			Size = UDim2.new(1, -150, 0, 14),
			Position = UDim2.fromOffset(48, 24),
			Font = Theme.FontRegular,
			TextSize = 10,
			Text = string.format("%s • %.2fx • %s", egg.moneyText or formatNumberShort(egg.moneyPerSec), egg.multiplier or 1.0, formatWeight(egg.weight or 395)),
			TextColor3 = Theme.SpeedCyan,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		-- Status on the right
		local statusLbl = Builder.label({
			Size = UDim2.new(0, 100, 1, 0),
			Position = UDim2.new(1, -108, 0, 0),
			Font = Theme.FontMedium,
			TextSize = 10,
			Text = egg.status or (isReady and "Ready to hatch" or "In inventory"),
			TextColor3 = isReady and Theme.ReadyGreen or Theme.AccentDark,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})

		card.MouseButton1Click:Connect(function()
			updateHeroCard(egg)
		end)

		return 54 -- height + gap
	end

	-- Sample dataset for testing/preview if live egg table is empty
	local function getSampleEggs()
		return {
			{
				uid = "egg_1",
				petName = "Sabertooth Tiger",
				rarity = "Mythic",
				moneyPerSec = 37700,
				moneyText = "+37.7K/s",
				multiplier = 1.04,
				weight = 395,
				ready = true,
				status = "Ready to hatch",
			},
			{
				uid = "egg_2",
				petName = "La Vacca Saturno Saturnita",
				rarity = "Cosmic",
				moneyPerSec = 5619000000,
				moneyText = "+5619M/s",
				multiplier = 6.22,
				weight = 178463,
				ready = false,
				status = "In inventory",
			},
			{
				uid = "egg_3",
				petName = "Dragon of Cosmos",
				rarity = "Divine",
				moneyPerSec = 98000000,
				moneyText = "+98.0M/s",
				multiplier = 4.50,
				weight = 84200,
				ready = false,
				status = "In inventory",
			},
			{
				uid = "egg_4",
				petName = "Golden Phoenix",
				rarity = "Legendary",
				moneyPerSec = 150000,
				moneyText = "+150K/s",
				multiplier = 2.10,
				weight = 1250,
				ready = false,
				status = "In inventory",
			},
		}
	end

	-- Refresh eggs and redraw list
	local function refresh()
		listsContainer:ClearAllChildren()

		local scanned = EggData.scan(false)
		local eggs = {}

		if scanned and #scanned > 0 then
			for _, item in ipairs(scanned) do
				local ready = (item.prompt ~= nil) or (item.distance and item.distance < 15)
				table.insert(eggs, {
					uid = item.uid,
					petName = item.petName or "Unknown",
					rarity = item.rarity or "Common",
					moneyPerSec = item.moneyPerSec or 50,
					moneyText = item.moneyText or formatNumberShort(item.moneyPerSec),
					multiplier = 1.0 + (getRarityRank(item.rarity) * 0.4),
					weight = 100 + (getRarityRank(item.rarity) * 450),
					ready = ready,
					status = ready and "Ready to hatch" or "In inventory",
				})
			end
		else
			eggs = getSampleEggs()
		end

		-- Filter
		local query = string.lower(string.gsub(activeFilter, "^%s*(.-)%s*$", "%1"))
		local filtered = {}
		for _, e in ipairs(eggs) do
			if query == "" 
				or string.find(string.lower(e.petName), query, 1, true)
				or string.find(string.lower(e.rarity), query, 1, true)
				or string.find(string.lower(e.status), query, 1, true)
			then
				table.insert(filtered, e)
			end
		end

		-- Sort
		table.sort(filtered, function(a, b)
			if sortBy == "Rarity" then
				return getRarityRank(a.rarity) > getRarityRank(b.rarity)
			elseif sortBy == "Value / sec" then
				return (a.moneyPerSec or 0) > (b.moneyPerSec or 0)
			elseif sortBy == "Weight" then
				return (a.weight or 0) > (b.weight or 0)
			else
				return tostring(a.status) < tostring(b.status)
			end
		end)

		-- Separate ready vs inventory
		local readyList = {}
		local invList = {}
		local totalRate = 0

		for _, e in ipairs(filtered) do
			totalRate = totalRate + (e.moneyPerSec or 0)
			if e.ready then
				table.insert(readyList, e)
			else
				table.insert(invList, e)
			end
		end

		-- Update summary
		summaryLabel.Text = string.format(
			"%d eggs • %d ready • 0 growing • %d in bag • Total %s",
			#filtered,
			#readyList,
			#invList,
			formatNumberShort(totalRate)
		)

		if not selectedEgg and #filtered > 0 then
			updateHeroCard(filtered[1])
		end

		-- Render Ready List
		local currentY = 0
		if #readyList > 0 then
			local readyHeader = Builder.label({
				Name = "ReadyHeader",
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.fromOffset(2, currentY),
				Font = Theme.FontBold,
				TextSize = 10,
				Text = string.format("READY TO HATCH (%d)", #readyList),
				TextColor3 = Theme.ReadyGreen,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = listsContainer,
			})
			currentY = currentY + 22

			for _, item in ipairs(readyList) do
				currentY = currentY + createEggCard(listsContainer, item, currentY, true)
			end
			currentY = currentY + 6
		end

		-- Render Inventory List
		if #invList > 0 then
			local invHeader = Builder.label({
				Name = "InvHeader",
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.fromOffset(2, currentY),
				Font = Theme.FontBold,
				TextSize = 10,
				Text = string.format("IN INVENTORY (%d)", #invList),
				TextColor3 = Theme.Accent,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = listsContainer,
			})
			currentY = currentY + 22

			for _, item in ipairs(invList) do
				currentY = currentY + createEggCard(listsContainer, item, currentY, false)
			end
		end

		listsContainer.Size = UDim2.new(1, -12, 0, currentY + 10)
		page.CanvasSize = UDim2.new(0, 0, 0, tab._y + currentY + 40)
	end

	tab._refreshEggs = refresh

	-- Search event
	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		activeFilter = searchInput.Text
		refresh()
	end)

	-- Initial population
	refresh()

	-- Periodic auto-refresh
	local running = true
	task.spawn(function()
		while running do
			task.wait(2.5)
			if running and page.Visible then
				refresh()
			end
		end
	end)

	cleanup.track(function()
		running = false
	end)
end

