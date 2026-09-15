-- The window's title bar: logo, title/subtitle and the close/minimise controls.
-- Extracted from the window shell so the shell only deals with layout, tabs and
-- dragging.
--
-- The controls are drawn from rotated bars rather than "-" and "x" text, so
-- they stay optically centred in their hit area at any font fallback.

local ctx = ...
local Theme = ctx.require("core/Theme")
local Builder = ctx.require("ui/Builder")

local TweenService = game:GetService("TweenService")

local HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local BUTTON_SIZE = 24
local BAR_THICKNESS = 2
local BAR_LENGTH = 11

local function bar(props)
	local instance = Builder.frame(Builder.merge({
		BackgroundColor3 = Theme.TextDim,
	}, props))
	Builder.corner(instance, 1)
	return instance
end

-- A round hit area whose glyph recolours on hover.
local function iconButton(config)
	local button = Builder.button({
		Name = config.name,
		Size = UDim2.fromOffset(config.size or BUTTON_SIZE, config.size or BUTTON_SIZE),
		Position = config.position,
		ZIndex = 8,
		Parent = config.parent,
	})
	Builder.pillCorner(button)

	local bars = config.build(button)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, HOVER, { BackgroundColor3 = Theme.SurfaceAlt }):Play()
		for _, glyph in ipairs(bars) do
			TweenService:Create(glyph, HOVER, { BackgroundColor3 = config.hoverColor or Theme.TextMain }):Play()
		end
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, HOVER, { BackgroundTransparency = 1 }):Play()
		button.BackgroundColor3 = Theme.Surface
		for _, glyph in ipairs(bars) do
			TweenService:Create(glyph, HOVER, { BackgroundColor3 = Theme.TextDim }):Play()
		end
	end)

	button.MouseButton1Click:Connect(function()
		local ok, err = pcall(config.onActivate)
		if not ok then
			warn("[Frost] Header action failed: " .. tostring(err))
		end
	end)

	return button, bars
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
	Builder.gradient(header, {
		ColorSequenceKeypoint.new(0, Theme.Surface),
		ColorSequenceKeypoint.new(1, Theme.Window),
	}, 90)

	local logo = Builder.frame({
		Name = "Logo",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(18, 17),
		BackgroundColor3 = config.accent,
		ZIndex = 7,
		Parent = header,
	})
	Builder.pillCorner(logo)

	local titleLabel = Builder.label({
		Name = "Title",
		Size = UDim2.new(0, 160, 0, 20),
		Position = UDim2.fromOffset(44, 13),
		Font = Theme.FontBold,
		TextSize = 15,
		Text = config.title or "Frost",
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme.TextMain,
		ZIndex = 7,
		Parent = header,
	})

	local subtitleLabel = Builder.label({
		Name = "Subtitle",
		Size = UDim2.new(0, 180, 0, 14),
		Position = UDim2.fromOffset(44, 31),
		Font = Theme.FontRegular,
		TextSize = 10,
		Text = config.subtitle or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme.TextDim,
		ZIndex = 7,
		Parent = header,
	})

	local statsLabel = Builder.label({
		Name = "StatsLabel",
		Size = UDim2.new(0, 120, 0, 20),
		Position = UDim2.new(1, -(BUTTON_SIZE * 2 + 155), 0, 16),
		Font = Theme.FontBold,
		TextSize = 11,
		Text = "FPS: -- | MS: --",
		TextColor3 = Theme.Success,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7,
		Parent = header,
	})

	-- Live FPS and Ping monitor
	local RunService = game:GetService("RunService")
	local Stats = game:GetService("Stats")
	local lastTime = os.clock()
	local frames = 0
	local statConn = RunService.RenderStepped:Connect(function()
		frames = frames + 1
		local now = os.clock()
		if now - lastTime >= 1 then
			local fps = math.round(frames / (now - lastTime))
			local ping = 0
			pcall(function()
				ping = math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
			end)
			statsLabel.Text = string.format("FPS: %d | MS: %d", fps, ping)
			if fps < 30 then
				statsLabel.TextColor3 = Theme.Danger
			elseif fps < 50 then
				statsLabel.TextColor3 = Theme.Warning
			else
				statsLabel.TextColor3 = Theme.Success
			end
			frames = 0
			lastTime = now
		end
	end)

	local minimizeGlyph, restoreGlyph
	iconButton({
		name = "Minimize",
		position = UDim2.new(1, -(BUTTON_SIZE * 2 + 26), 0, 14),
		parent = header,
		build = function(parent)
			minimizeGlyph = bar({
				Size = UDim2.fromOffset(BAR_LENGTH, BAR_THICKNESS),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 9,
				Parent = parent,
			})
			restoreGlyph = bar({
				Size = UDim2.fromOffset(BAR_THICKNESS, BAR_LENGTH),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Visible = false,
				ZIndex = 9,
				Parent = parent,
			})
			return { minimizeGlyph, restoreGlyph }
		end,
		onActivate = config.onMinimize,
	})

	iconButton({
		name = "Close",
		position = UDim2.new(1, -(BUTTON_SIZE + 16), 0, 14),
		parent = header,
		hoverColor = Theme.Danger,
		build = function(parent)
			local first = bar({
				Size = UDim2.fromOffset(BAR_LENGTH, BAR_THICKNESS),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = 45,
				ZIndex = 9,
				Parent = parent,
			})
			local second = bar({
				Size = UDim2.fromOffset(BAR_LENGTH, BAR_THICKNESS),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = -45,
				ZIndex = 9,
				Parent = parent,
			})
			return { first, second }
		end,
		onActivate = config.onClose,
	})

	return {
		frame = header,
		titleLabel = titleLabel,
		subtitleLabel = subtitleLabel,
		statsLabel = statsLabel,
		destroy = function()
			if statConn then
				statConn:Disconnect()
				statConn = nil
			end
		end,
		setMinimized = function(minimized)
			if restoreGlyph then
				restoreGlyph.Visible = minimized
			end
			if statsLabel then
				statsLabel.Visible = not minimized
			end
		end,
	}
end

return Header
