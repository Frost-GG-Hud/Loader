-- Ajjans Header Bar:
-- Left: AJJANS branding
-- Middle/Right: FPS, PING, VER live monitor
-- Far Right: Search bar & Window Controls

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")

local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUTTON_SIZE = 20

local function iconButton(config)
	local button = Builder.button({
		Name = config.name,
		Size = UDim2.fromOffset(config.size or BUTTON_SIZE, config.size or BUTTON_SIZE),
		Position = config.position,
		BackgroundColor3 = Theme.SurfaceAlt,
		BackgroundTransparency = 0.5,
		ZIndex = 8,
		Parent = config.parent,
	})
	Builder.pillCorner(button)

	local glyph = Builder.label({
		Name = "Glyph",
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.FontBold,
		TextSize = config.textSize or 11,
		Text = config.text or "",
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9,
		Parent = button,
	})

	button.MouseEnter:Connect(function()
		TweenService:Create(button, HOVER, { BackgroundColor3 = config.hoverBg or Theme.Accent, BackgroundTransparency = 0 }):Play()
		TweenService:Create(glyph, HOVER, { TextColor3 = Theme.White }):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, HOVER, { BackgroundColor3 = Theme.SurfaceAlt, BackgroundTransparency = 0.5 }):Play()
		TweenService:Create(glyph, HOVER, { TextColor3 = Theme.TextDim }):Play()
	end)

	button.MouseButton1Click:Connect(function()
		pcall(config.onActivate)
	end)

	return button
end

local Header = {}

function Header.new(config)
	local header = Builder.frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, Theme.Metrics.HeaderHeight),
		BackgroundColor3 = Theme.Surface,
		ZIndex = 6,
		ClipsDescendants = false,
		Parent = config.parent,
	})
	Builder.corner(header, Theme.Metrics.CornerHeader)
	Builder.stroke(header, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.3,
	})

	-- Left Branding: "AJJANS"
	local brandLabel = Builder.label({
		Name = "BrandTitle",
		Size = UDim2.new(0, 130, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = Theme.FontBold,
		TextSize = 15,
		Text = "AJJANS",
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = header,
	})

	-- Search Bar on the Right
	local searchBox = Builder.frame({
		Name = "HeaderSearch",
		Size = UDim2.new(0, 140, 0, 26),
		Position = UDim2.new(1, -195, 0.5, -13),
		BackgroundColor3 = Theme.Background,
		ZIndex = 7,
		Parent = header,
	})
	Builder.corner(searchBox, 6)
	local searchStroke = Builder.stroke(searchBox, {
		Color = Theme.Border,
		Thickness = 1,
		Transparency = 0.3,
	})

	local searchInput = Builder.new("TextBox", {
		Name = "Input",
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Font = Theme.FontRegular,
		TextSize = 10,
		Text = "",
		PlaceholderText = "Search...",
		PlaceholderColor3 = Theme.TextMuted,
		TextColor3 = Theme.TextMain,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 8,
		Parent = searchBox,
	})

	searchInput.Focused:Connect(function()
		searchStroke.Color = Theme.Accent
		searchStroke.Transparency = 0
	end)

	searchInput.FocusLost:Connect(function()
		searchStroke.Color = Theme.Border
		searchStroke.Transparency = 0.3
	end)

	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		if config.onSearchChanged then
			pcall(config.onSearchChanged, searchInput.Text)
		end
	end)

	-- Stats Monitor: FPS: 167  PING: 5ms  VER: V.528
	local statsFrame = Builder.frame({
		Name = "StatsMonitor",
		Size = UDim2.new(0, 210, 0, 24),
		Position = UDim2.new(1, -415, 0.5, -12),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = header,
	})

	local statsLabel = Builder.label({
		Name = "StatsLabel",
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.FontMedium,
		TextSize = 10,
		Text = "FPS: 60  PING: 15ms  VER: V.528",
		TextColor3 = Theme.AccentDark,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
		Parent = statsFrame,
	})

	-- Live FPS & Ping ticker
	local fpsCount = 0
	local fpsTime = tick()
	local currentFps = 60
	local heartbeatConn = RunService.Heartbeat:Connect(function()
		fpsCount = fpsCount + 1
		local now = tick()
		if now - fpsTime >= 0.75 then
			currentFps = math.floor(fpsCount / (now - fpsTime))
			fpsCount = 0
			fpsTime = now
			local ping = 10
			pcall(function()
				local net = StatsService.Network.ServerStatsItem["Data Ping"]
				if net then
					ping = math.floor(net:GetValue())
				end
			end)
			statsLabel.Text = string.format("FPS: %d  PING: %dms  VER: V.528", currentFps, ping)
		end
	end)

	-- Window action buttons (Minimize & Close)
	local controls = Builder.frame({
		Name = "Controls",
		Size = UDim2.new(0, 46, 1, 0),
		Position = UDim2.new(1, -50, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = header,
	})

	local minimizeButton = iconButton({
		name = "Minimize",
		position = UDim2.new(0, 0, 0.5, -10),
		text = "-",
		parent = controls,
		onActivate = function()
			if config.onMinimize then
				config.onMinimize()
			end
		end,
	})

	local closeButton = iconButton({
		name = "Close",
		position = UDim2.new(0, 24, 0.5, -10),
		text = "X",
		hoverBg = Theme.Danger,
		parent = controls,
		onActivate = function()
			if config.onClose then
				config.onClose()
			end
		end,
	})

	return {
		frame = header,
		searchBox = searchBox,
		searchInput = searchInput,
		statsLabel = statsLabel,
		destroy = function()
			if heartbeatConn then
				heartbeatConn:Disconnect()
				heartbeatConn = nil
			end
		end,
	}
end

return Header
