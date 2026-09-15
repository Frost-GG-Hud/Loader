-- Single source of truth for every colour and metric the UI uses.

local ctx = ...

local Theme = {
	Background = Color3.fromRGB(7, 15, 12),
	Window = Color3.fromRGB(10, 20, 16),
	Surface = Color3.fromRGB(13, 26, 21),
	SurfaceAlt = Color3.fromRGB(18, 36, 29),
	Card = Color3.fromRGB(16, 32, 26),
	CardHover = Color3.fromRGB(22, 44, 35),
	Accent = Color3.fromRGB(46, 204, 113),
	AccentDark = Color3.fromRGB(33, 148, 82),
	AccentGlow = Color3.fromRGB(80, 235, 145),
	TextMain = Color3.fromRGB(240, 252, 246),
	TextDim = Color3.fromRGB(155, 185, 170),
	TextMuted = Color3.fromRGB(90, 125, 110),
	Border = Color3.fromRGB(25, 52, 41),
	BorderActive = Color3.fromRGB(46, 204, 113),
	Danger = Color3.fromRGB(255, 80, 95),
	Warning = Color3.fromRGB(255, 185, 60),
	Success = Color3.fromRGB(46, 204, 113),
	White = Color3.new(1, 1, 1),
}

Theme.FontRegular = Enum.Font.Gotham
Theme.FontMedium = Enum.Font.GothamSemibold
Theme.FontBold = Enum.Font.GothamBold

Theme.Metrics = {
	HeaderHeight = 48,
	TabRailWidth = 145,
	ContentInset = 158,
	ContentTop = 56,
	Gutter = 10,
	CornerWindow = 12,
	CornerHeader = 12,
	CornerCard = 8,
	CornerSmall = 6,
	RowHeight = 39,
	RowGap = 8,
	SectionHeight = 26,
	MinWidth = 520,
	MinHeight = 340,
	MaxWidth = 950,
	MaxHeight = 720,
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

return Theme
