-- Single source of truth for every colour and metric the UI uses.

local ctx = ...

local Theme = {
	Background = Color3.fromRGB(6, 17, 14),
	Window = Color3.fromRGB(10, 27, 22),
	Surface = Color3.fromRGB(14, 39, 31),
	SurfaceAlt = Color3.fromRGB(21, 54, 43),
	Card = Color3.fromRGB(17, 45, 36),
	CardHover = Color3.fromRGB(24, 60, 48),
	Accent = Color3.fromRGB(108, 211, 169),
	AccentDark = Color3.fromRGB(65, 157, 119),
	TextMain = Color3.fromRGB(242, 245, 247),
	TextDim = Color3.fromRGB(153, 165, 176),
	TextMuted = Color3.fromRGB(110, 122, 133),
	Border = Color3.fromRGB(56, 64, 72),
	Danger = Color3.fromRGB(235, 94, 94),
	Warning = Color3.fromRGB(232, 168, 74),
	Success = Color3.fromRGB(94, 201, 146),
	White = Color3.new(1, 1, 1),
}

Theme.FontRegular = Enum.Font.Gotham
Theme.FontMedium = Enum.Font.GothamSemibold
Theme.FontBold = Enum.Font.GothamBold

Theme.Metrics = {
	HeaderHeight = 52,
	TabRailWidth = 86,
	ContentInset = 102,
	ContentTop = 62,
	Gutter = 10,
	CornerWindow = 16,
	CornerHeader = 16,
	CornerCard = 9,
	CornerSmall = 6,
	RowHeight = 39,
	RowGap = 8,
	MinWidth = 380,
	MinHeight = 260,
	MaxWidth = 900,
	MaxHeight = 700,
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
