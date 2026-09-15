-- Single source of truth for every colour and metric the UI uses.

local ctx = ...

local Theme = {
	Background = Color3.fromRGB(13, 14, 20),
	Window = Color3.fromRGB(17, 18, 26),
	Surface = Color3.fromRGB(22, 23, 34),
	SurfaceAlt = Color3.fromRGB(28, 30, 44),
	Card = Color3.fromRGB(25, 27, 40),
	CardHover = Color3.fromRGB(33, 36, 54),
	Accent = Color3.fromRGB(80, 180, 255),
	AccentDark = Color3.fromRGB(50, 130, 200),
	AccentGlow = Color3.fromRGB(120, 210, 255),
	TextMain = Color3.fromRGB(245, 246, 252),
	TextDim = Color3.fromRGB(155, 162, 185),
	TextMuted = Color3.fromRGB(100, 106, 128),
	Border = Color3.fromRGB(36, 39, 58),
	BorderActive = Color3.fromRGB(80, 180, 255),
	Danger = Color3.fromRGB(255, 80, 95),
	Warning = Color3.fromRGB(255, 185, 60),
	Success = Color3.fromRGB(80, 210, 140),
	Info = Color3.fromRGB(80, 180, 255),
	White = Color3.new(1, 1, 1),
}

Theme.FontRegular = Enum.Font.Gotham
Theme.FontMedium = Enum.Font.GothamSemibold
Theme.FontBold = Enum.Font.GothamBold

Theme.Metrics = {
	HeaderHeight = 50,
	TabRailWidth = 148,
	ContentInset = 162,
	ContentTop = 58,
	Gutter = 10,
	CornerWindow = 12,
	CornerHeader = 12,
	CornerCard = 8,
	CornerSmall = 6,
	RowHeight = 39,
	RowGap = 8,
	SectionHeight = 26,
	MinWidth = 540,
	MinHeight = 360,
	MaxWidth = 960,
	MaxHeight = 740,
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
