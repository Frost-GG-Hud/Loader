-- Ajjans Dark Crimson Theme
-- Single source of truth for every colour and metric the UI uses.

local ctx = ...

local Theme = {
	Background = Color3.fromRGB(13, 4, 7),
	Window = Color3.fromRGB(18, 6, 10),
	Sidebar = Color3.fromRGB(22, 7, 12),
	Surface = Color3.fromRGB(26, 9, 15),
	SurfaceAlt = Color3.fromRGB(33, 12, 19),
	Card = Color3.fromRGB(28, 10, 16),
	CardHover = Color3.fromRGB(38, 14, 22),
	
	-- Crimson Accent
	Accent = Color3.fromRGB(235, 35, 45),
	AccentDark = Color3.fromRGB(165, 20, 28),
	AccentGlow = Color3.fromRGB(255, 65, 75),
	
	-- Text
	TextMain = Color3.fromRGB(248, 246, 246),
	TextDim = Color3.fromRGB(175, 158, 162),
	TextMuted = Color3.fromRGB(115, 95, 100),
	
	-- Borders
	Border = Color3.fromRGB(48, 16, 24),
	BorderActive = Color3.fromRGB(235, 35, 45),
	BorderReady = Color3.fromRGB(0, 230, 118),
	
	-- Status & Indicators
	Danger = Color3.fromRGB(255, 42, 58),
	Warning = Color3.fromRGB(255, 213, 79),
	Success = Color3.fromRGB(0, 230, 118),
	Info = Color3.fromRGB(0, 229, 255),
	White = Color3.new(1, 1, 1),
	
	-- Stat Highlights
	SpeedCyan = Color3.fromRGB(0, 229, 255),
	WeightGold = Color3.fromRGB(255, 213, 79),
	ReadyGreen = Color3.fromRGB(0, 230, 118),
	
	-- Rarities
	Rarities = {
		Common = Color3.fromRGB(180, 190, 205),
		Uncommon = Color3.fromRGB(85, 235, 120),
		Rare = Color3.fromRGB(60, 160, 255),
		Epic = Color3.fromRGB(185, 80, 255),
		Legendary = Color3.fromRGB(255, 185, 30),
		Mythic = Color3.fromRGB(255, 55, 100),
		Cosmic = Color3.fromRGB(186, 104, 200),
		Divine = Color3.fromRGB(0, 245, 220),
		Secret = Color3.fromRGB(255, 230, 80),
	}
}

Theme.FontRegular = Enum.Font.Gotham
Theme.FontMedium = Enum.Font.GothamSemibold
Theme.FontBold = Enum.Font.GothamBold

Theme.Metrics = {
	HeaderHeight = 44,
	TabRailWidth = 140,
	ContentInset = 152,
	ContentTop = 52,
	Gutter = 8,
	CornerWindow = 10,
	CornerHeader = 10,
	CornerCard = 8,
	CornerSmall = 6,
	RowHeight = 36,
	RowGap = 6,
	SectionHeight = 24,
	MinWidth = 580,
	MinHeight = 420,
	MaxWidth = 960,
	MaxHeight = 760,
}

function Theme.colorForKind(kind)
	if kind == "error" then
		return Theme.Danger
	elseif kind == "success" then
		return Theme.Success
	elseif kind == "warning" then
		return Theme.Warning
	end
	return Theme.Accent
end

function Theme.getRarityColor(rarityName)
	if type(rarityName) == "string" and Theme.Rarities[rarityName] then
		return Theme.Rarities[rarityName]
	end
	return Theme.Accent
end

return Theme
