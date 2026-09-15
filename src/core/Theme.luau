-- Single source of truth for every colour and metric the UI uses.

local ctx = ...

local Theme = {
	Background = Color3.fromRGB(12, 14, 20),
	Window = Color3.fromRGB(16, 20, 28),
	Surface = Color3.fromRGB(22, 27, 38),
	SurfaceAlt = Color3.fromRGB(30, 37, 52),
	Card = Color3.fromRGB(25, 31, 45),
	CardHover = Color3.fromRGB(34, 42, 60),
	Accent = Color3.fromRGB(0, 215, 255),
	AccentDark = Color3.fromRGB(0, 145, 185),
	AccentGlow = Color3.fromRGB(80, 230, 255),
	TextMain = Color3.fromRGB(245, 248, 255),
	TextDim = Color3.fromRGB(165, 178, 200),
	TextMuted = Color3.fromRGB(105, 118, 140),
	Border = Color3.fromRGB(44, 54, 76),
	BorderActive = Color3.fromRGB(0, 215, 255),
	Danger = Color3.fromRGB(255, 80, 95),
	Warning = Color3.fromRGB(255, 185, 60),
	Success = Color3.fromRGB(65, 225, 135),
	White = Color3.new(1, 1, 1),
}

Theme.FontRegular = Enum.Font.Gotham
Theme.FontMedium = Enum.Font.GothamSemibold
Theme.FontBold = Enum.Font.GothamBold

Theme.Metrics = {
	HeaderHeight = 52,
	TabRailWidth = 135,
	ContentInset = 148,
	ContentTop = 62,
	Gutter = 10,
	CornerWindow = 14,
	CornerHeader = 14,
	CornerCard = 8,
	CornerSmall = 6,
	RowHeight = 39,
	RowGap = 8,
	SectionHeight = 26,
	MinWidth = 420,
	MinHeight = 300,
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
