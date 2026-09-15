local Config = {
    BaseUrl = "",
    RepoOwner = "Frost-GG-Hud",
    RepoName = "Loader",
    Branch = "main",
    KeyFile = "keys.json",
}

print("[Frost] main loaded")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local waitSafe = function(t)
    if task and task.wait then
        task.wait(t)
    else
        wait(t)
    end
end

local function httpGet(url)
    pcall(function()
        HttpService.HttpEnabled = true
    end)
    local ok, res = pcall(function()
        return HttpService:HttpGet(url)
    end)
    if not ok then
        ok, res = pcall(function()
            return game:HttpGet(url)
        end)
    end
    if not ok then
        return nil
    end
    return res
end

local function getRaw(path)
    if Config.BaseUrl ~= "" then
        return httpGet(Config.BaseUrl .. "/" .. path)
    end
    return httpGet("https://raw.githubusercontent.com/" .. Config.RepoOwner .. "/" .. Config.RepoName .. "/" .. Config.Branch .. "/" .. path)
end

local function fetchServerKey()
    local data = getRaw(Config.KeyFile)
    if not data then
        return ""
    end
    local ok, parsed = pcall(function()
        return HttpService:JSONDecode(data)
    end)
    if ok and parsed and parsed.current then
        return parsed.current
    end
    return ""
end

local function normalizeKey(key)
    return (string.gsub(string.lower(tostring(key or "")), "%s+", ""))
end

local function getCharacter()
    local char = LocalPlayer.Character
    if not char then
        pcall(function()
            LocalPlayer.CharacterAdded:Wait()
        end)
        char = LocalPlayer.Character
    end
    return char
end

local function getHumanoid(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function drawCircle(label, parent, r, color)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, r * 2, 0, r * 2)
    frame.Position = UDim2.fromOffset(0, 0)
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame
    return frame
end

local Theme = {
    Background = Color3.fromRGB(12, 16, 18),
    Window = Color3.fromRGB(20, 24, 29),
    Surface = Color3.fromRGB(28, 34, 41),
    SurfaceAlt = Color3.fromRGB(35, 42, 49),
    Card = Color3.fromRGB(30, 38, 45),
    Accent = Color3.fromRGB(112, 209, 170),
    AccentDark = Color3.fromRGB(72, 153, 117),
    TextMain = Color3.fromRGB(242, 245, 247),
    TextDim = Color3.fromRGB(153, 165, 176),
    Border = Color3.fromRGB(56, 64, 72),
    Danger = Color3.fromRGB(235, 94, 94),
    Success = Color3.fromRGB(94, 201, 146),
}

local Lib = {}

function Lib.CreateWindow(opts)
    opts = opts or {}
    local title = opts.Title or "Frost"
    local size = opts.Size or Vector2.new(430, 360)
    local accent = opts.Accent or Theme.Accent

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FrostGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    if gethui then
        pcall(function()
            screenGui.Parent = gethui()
        end)
    end
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local ambient = Instance.new("Frame")
    ambient.BackgroundColor3 = Color3.fromRGB(95, 129, 112)
    ambient.BackgroundTransparency = 0.48
    ambient.Size = UDim2.new(1, 0, 1, 0)
    ambient.BorderSizePixel = 0
    ambient.Parent = screenGui

    local window = Instance.new("Frame")
    window.Name = "Window"
    window.BackgroundColor3 = Theme.Window
    window.BorderSizePixel = 0
    window.AnchorPoint = Vector2.new(0, 0)
    window.ZIndex = 4
    window.Parent = screenGui

    local vs = workspace.CurrentCamera.ViewportSize
    window.Size = UDim2.fromOffset(size.X, size.Y)
    window.Position = UDim2.fromOffset(
        math.max(24, (vs.X - size.X) / 2),
        math.max(40, (vs.Y - size.Y) / 2)
    )

    local winCorner = Instance.new("UICorner")
    winCorner.CornerRadius = UDim.new(0, 16)
    winCorner.Parent = window

    local winStroke = Instance.new("UIStroke")
    winStroke.Color = Color3.fromRGB(120, 130, 138)
    winStroke.Thickness = 1.2
    winStroke.Transparency = 0.25
    winStroke.Parent = window

    local shadow = Instance.new("ImageLabel")
    shadow.BackgroundTransparency = 1
    shadow.Size = UDim2.new(1, 28, 1, 28)
    shadow.Position = UDim2.fromOffset(-14, -14)
    shadow.Image = "rbxassetid://131604521"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.8
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.ZIndex = 0
    shadow.Parent = window

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 54)
    header.BackgroundColor3 = Theme.Surface
    header.BorderSizePixel = 0
    header.Parent = window

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 16)
    headerCorner.Parent = header

    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Surface),
        ColorSequenceKeypoint.new(1, Theme.Window),
    })
    headerGradient.Rotation = 90
    headerGradient.Parent = header

    local logo = drawCircle("_Logo", header, 9, accent)
    logo.Position = UDim2.fromOffset(18, 14)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -110, 0, 22)
    titleLabel.Position = UDim2.fromOffset(38, 15)
    titleLabel.Text = title
    titleLabel.TextColor3 = Theme.TextMain
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.Parent = header

    local metaLabel = Instance.new("TextLabel")
    metaLabel.BackgroundTransparency = 1
    metaLabel.Size = UDim2.new(1, -110, 0, 16)
    metaLabel.Position = UDim2.fromOffset(38, 31)
    metaLabel.Text = "Premium script hub"
    metaLabel.TextColor3 = Theme.TextDim
    metaLabel.TextXAlignment = Enum.TextXAlignment.Left
    metaLabel.Font = Enum.Font.Gotham
    metaLabel.TextSize = 10
    metaLabel.Parent = header

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "Close"
    closeButton.Size = UDim2.fromOffset(20, 20)
    closeButton.Position = UDim2.new(1, -28, 0, 17)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = "×"
    closeButton.TextColor3 = Theme.TextDim
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 18
    closeButton.Parent = header
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Name = "Minimize"
    minimizeButton.Size = UDim2.fromOffset(20, 20)
    minimizeButton.Position = UDim2.new(1, -54, 0, 17)
    minimizeButton.BackgroundTransparency = 1
    minimizeButton.Text = "-"
    minimizeButton.TextColor3 = Theme.TextDim
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.TextSize = 18
    minimizeButton.Parent = header

    local tabList = Instance.new("ScrollingFrame")
    tabList.Name = "Tabs"
    tabList.Size = UDim2.new(1, -30, 0, 36)
    tabList.Position = UDim2.fromOffset(15, 60)
    tabList.BackgroundTransparency = 1
    tabList.BorderSizePixel = 0
    tabList.ScrollBarThickness = 0
    tabList.AutomaticCanvasSize = Enum.AutomaticSize.X
    tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabList.Parent = window

    local contentArea = Instance.new("Frame")
    contentArea.Name = "Content"
    contentArea.Size = UDim2.new(1, -18, 1, -106)
    contentArea.Position = UDim2.fromOffset(9, 98)
    contentArea.BackgroundTransparency = 1
    contentArea.ClipsDescendants = true
    contentArea.Parent = window

    local contentBG = Instance.new("Frame")
    contentBG.BackgroundColor3 = Theme.Surface
    contentBG.BorderSizePixel = 0
    contentBG.Size = UDim2.new(1, 0, 1, 0)
    contentBG.Parent = contentArea
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 12)
    bgCorner.Parent = contentBG

    local normalSize = UDim2.fromOffset(size.X, size.Y)
    local minimized = false
    minimizeButton.MouseButton1Click:Connect(function()
        minimized = not minimized
        tabList.Visible = not minimized
        contentArea.Visible = not minimized
        window.Size = minimized and UDim2.fromOffset(size.X, 54) or normalSize
        minimizeButton.Text = minimized and "+" or "-"
    end)

    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2.fromOffset(20, 20)
    resizeHandle.Position = UDim2.new(1, -20, 1, -20)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Text = ""
    resizeHandle.ZIndex = 8
    resizeHandle.Parent = window

    local resizing = false
    local resizeStart
    local resizeSize
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resizeStart = input.Position
            resizeSize = window.AbsoluteSize
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resizeStart
            local width = math.clamp(resizeSize.X + delta.X, 380, 760)
            local height = math.clamp(resizeSize.Y + delta.Y, 260, 600)
            window.Size = UDim2.fromOffset(width, height)
            normalSize = window.Size
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end)

    local dragObject
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragObject = input
        end
    end)
    header.InputEnded:Connect(function(input)
        if input == dragObject then
            dragObject = nil
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragObject and input.UserInputType == Enum.UserInputType.MouseMovement then
            local pos = UserInputService:GetMouseLocation()
            window.Position = UDim2.fromOffset(
                math.clamp(pos.X - window.AbsoluteSize.X / 2, 0, workspace.CurrentCamera.ViewportSize.X - window.AbsoluteSize.X),
                math.clamp(pos.Y - 10, 0, workspace.CurrentCamera.ViewportSize.Y - window.AbsoluteSize.Y)
            )
        end
    end)

    local api = { _window = window, _tabs = {}, _activeTab = nil, _accent = accent }
    local tabIndex = 0

    function api.AddTab(name)
        tabIndex = tabIndex + 1

        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 86, 0, 30)
        btn.Position = UDim2.fromOffset((tabIndex - 1) * 92, 0)
        btn.BackgroundColor3 = Theme.SurfaceAlt
        btn.BorderSizePixel = 0
        btn.Text = name
        btn.TextColor3 = Theme.TextDim
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.Parent = tabList
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        local page = Instance.new("ScrollingFrame")
        page.Name = name
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 0
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.Visible = false
        page.Parent = contentArea

        local spacing = 10
        local tab = {
            _btn = btn,
            _page = page,
            _accent = accent,
            AddLabel = function(self, text, dim)
                spacing = spacing + 6
                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Size = UDim2.new(1, -16, 0, 18)
                lbl.Position = UDim2.fromOffset(12, spacing)
                lbl.Text = text
                lbl.TextColor3 = dim and Theme.TextDim or Theme.TextMain
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 12
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = page
                spacing = spacing + 18
            end,
            AddButton = function(self, text, callback, danger)
                spacing = spacing + 8
                local card = Instance.new("Frame")
                card.BackgroundColor3 = Theme.Card
                card.BorderSizePixel = 0
                card.Size = UDim2.new(1, -12, 0, 39)
                card.Position = UDim2.fromOffset(6, spacing)
                card.Parent = page
                local cardCorner = Instance.new("UICorner")
                cardCorner.CornerRadius = UDim.new(0, 9)
                cardCorner.Parent = card

                local btnLabel = Instance.new("TextButton")
                btnLabel.BackgroundTransparency = 1
                btnLabel.Size = UDim2.new(1, -18, 1, 0)
                btnLabel.Position = UDim2.fromOffset(12, 0)
                btnLabel.Text = text
                btnLabel.TextColor3 = danger and Theme.Danger or Theme.TextMain
                btnLabel.Font = Enum.Font.GothamSemibold
                btnLabel.TextSize = 13
                btnLabel.TextXAlignment = Enum.TextXAlignment.Left
                btnLabel.Parent = card

                local accentBar = Instance.new("Frame")
                accentBar.BackgroundColor3 = danger and Theme.Danger or accent
                accentBar.BorderSizePixel = 0
                accentBar.Size = UDim2.new(0, 0, 0, 3)
                accentBar.Position = UDim2.new(0, 0, 1, -3)
                accentBar.Parent = card
                local barCorner = Instance.new("UICorner")
                barCorner.CornerRadius = UDim.new(0, 3)
                barCorner.Parent = accentBar

                btnLabel.MouseButton1Click:Connect(function()
                    if callback then
                        pcall(function()
                            callback()
                        end)
                    end
                end)

                local hoverTween = TweenService:Create(accentBar, TweenInfo.new(0.12), { Size = UDim2.new(1, 0, 0, 3) })
                btnLabel.MouseEnter:Connect(function()
                    hoverTween:Play()
                end)
                btnLabel.MouseLeave:Connect(function()
                    hoverTween:Cancel()
                    accentBar.Size = UDim2.new(0, 0, 0, 3)
                end)

                spacing = spacing + 45
            end,
            AddToggle = function(self, text, default, onChange)
                spacing = spacing + 8
                local card = Instance.new("Frame")
                card.BackgroundColor3 = Theme.Card
                card.BorderSizePixel = 0
                card.Size = UDim2.new(1, -12, 0, 40)
                card.Position = UDim2.fromOffset(6, spacing)
                card.Parent = page
                local cardCorner = Instance.new("UICorner")
                cardCorner.CornerRadius = UDim.new(0, 9)
                cardCorner.Parent = card

                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Size = UDim2.new(1, -54, 1, 0)
                lbl.Position = UDim2.fromOffset(12, 0)
                lbl.Text = text
                lbl.TextColor3 = Theme.TextMain
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 13
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = card

                local value = default == true
                local toggle = Instance.new("Frame")
                toggle.Size = UDim2.fromOffset(42, 20)
                toggle.Position = UDim2.new(1, -54, 0.5, -10)
                toggle.BackgroundColor3 = Theme.Background
                toggle.BorderSizePixel = 0
                toggle.Parent = card
                local toggleCorner = Instance.new("UICorner")
                toggleCorner.CornerRadius = UDim.new(1, 0)
                toggleCorner.Parent = toggle

                local knob = Instance.new("Frame")
                knob.Size = UDim2.fromOffset(14, 14)
                knob.Position = UDim2.fromOffset(3, 3)
                knob.BackgroundColor3 = Theme.TextDim
                knob.BorderSizePixel = 0
                knob.Parent = toggle
                local knobCorner = Instance.new("UICorner")
                knobCorner.CornerRadius = UDim.new(1, 0)
                knobCorner.Parent = knob

                local function apply()
                    TweenService:Create(toggle, TweenInfo.new(0.15), {
                        BackgroundColor3 = value and accent or Theme.Background,
                    }):Play()
                    TweenService:Create(knob, TweenInfo.new(0.15), {
                        Position = value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
                        BackgroundColor3 = value and Color3.new(1, 1, 1) or Theme.TextDim,
                    }):Play()
                end

                local click = Instance.new("TextButton")
                click.BackgroundTransparency = 1
                click.Size = UDim2.new(1, 0, 1, 0)
                click.Text = ""
                click.Parent = card
                click.MouseButton1Click:Connect(function()
                    value = not value
                    apply()
                    if onChange then
                        pcall(function()
                            onChange(value)
                        end)
                    end
                end)
                apply()
                spacing = spacing + 46
                return {
                    Get = function()
                        return value
                    end,
                    Set = function(v)
                        value = v == true
                        apply()
                        if onChange then
                            pcall(function()
                                onChange(value)
                            end)
                        end
                    end,
                }
            end,
            AddSlider = function(self, text, min, max, default, onChange)
                spacing = spacing + 8
                local card = Instance.new("Frame")
                card.BackgroundColor3 = Theme.Card
                card.BorderSizePixel = 0
                card.Size = UDim2.new(1, -12, 0, 48)
                card.Position = UDim2.fromOffset(6, spacing)
                card.Parent = page
                local cardCorner = Instance.new("UICorner")
                cardCorner.CornerRadius = UDim.new(0, 9)
                cardCorner.Parent = card

                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Size = UDim2.new(1, -70, 0, 18)
                lbl.Position = UDim2.fromOffset(12, 5)
                lbl.Text = text
                lbl.TextColor3 = Theme.TextMain
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 12
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = card

                local valLabel = Instance.new("TextLabel")
                valLabel.BackgroundColor3 = Theme.SurfaceAlt
                valLabel.BorderSizePixel = 0
                valLabel.Size = UDim2.fromOffset(52, 22)
                valLabel.Position = UDim2.new(1, -62, 0, 4)
                valLabel.Text = tostring(default)
                valLabel.TextColor3 = accent
                valLabel.Font = Enum.Font.GothamBold
                valLabel.TextSize = 12
                valLabel.TextXAlignment = Enum.TextXAlignment.Center
                valLabel.Parent = card
                local valCorner = Instance.new("UICorner")
                valCorner.CornerRadius = UDim.new(0, 6)
                valCorner.Parent = valLabel

                local track = Instance.new("Frame")
                track.Size = UDim2.new(1, -18, 0, 4)
                track.Position = UDim2.new(0, 12, 1, -12)
                track.BackgroundColor3 = Theme.Background
                track.BorderSizePixel = 0
                track.Parent = card
                local trackCorner = Instance.new("UICorner")
                trackCorner.CornerRadius = UDim.new(1, 0)
                trackCorner.Parent = track

                local fill = Instance.new("Frame")
                fill.BackgroundColor3 = accent
                fill.BorderSizePixel = 0
                fill.Size = UDim2.new(0, 0, 1, 0)
                fill.Parent = track
                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(1, 0)
                fillCorner.Parent = fill

                local grab = Instance.new("TextButton")
                grab.BackgroundTransparency = 1
                grab.Size = UDim2.new(0, 18, 0, 18)
                grab.Position = UDim2.new(0, -9, 1, -9)
                grab.Text = ""
                grab.Parent = card

                local value = default
                local updating = false
                local function update(fromX)
                    local absX = track.AbsolutePosition.X
                    local absW = track.AbsoluteSize.X
                    local frac = math.clamp((fromX - absX) / absW, 0, 1)
                    value = math.round(min + (max - min) * frac)
                    fill.Size = UDim2.fromScale(frac, 1)
                    valLabel.Text = tostring(value)
                    if onChange and not updating then
                        updating = true
                        pcall(function()
                            onChange(value)
                        end)
                        updating = false
                    end
                end
                grab.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        update(input.Position.X)
                        local conn
                        conn = UserInputService.InputChanged:Connect(function(move)
                            if move.UserInputType == Enum.UserInputType.MouseMovement then
                                update(move.Position.X)
                            end
                        end)
                        local releaseConn
                        releaseConn = UserInputService.InputEnded:Connect(function(release)
                            if release.UserInputType == Enum.UserInputType.MouseButton1 then
                                conn:Disconnect()
                                releaseConn:Disconnect()
                            end
                        end)
                    end
                end)
                update(track.AbsolutePosition.X + (value - min) / (max - min) * track.AbsoluteSize.X)
                spacing = spacing + 54
                return {
                    Get = function()
                        return value
                    end,
                }
            end,
        }
        table.insert(api._tabs, tab)

        btn.MouseButton1Click:Connect(function()
            api.Select(name)
        end)
        return tab
    end

    function api.Select(name)
        for _, t in ipairs(api._tabs) do
            local active = t._btn.Name == name
            t._page.Visible = active
            t._btn.BackgroundColor3 = active and accent or Theme.SurfaceAlt
            t._btn.TextColor3 = active and Color3.new(1, 1, 1) or Theme.TextDim
        end
    end

    function api.Destroy()
        screenGui:Destroy()
    end

    function api.SetTitle(text)
        titleLabel.Text = text
    end

    if api._tabs and #api._tabs > 0 then
        api.Select(api._tabs[1]._btn.Name)
    end

    return api
end

local keyState = {
    Valid = false,
    ServerKey = "",
}

local buildHub

local function buildKeyGui()
    print("[Frost] Building key GUI")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FrostAuth"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    if gethui then
        pcall(function()
            screenGui.Parent = gethui()
        end)
    end
    if not screenGui.Parent then
        pcall(function()
            screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end)
    end

    local dim = Instance.new("Frame")
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 0.58
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.Parent = screenGui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(390, 300)
    card.BackgroundColor3 = Theme.Window
    card.BorderSizePixel = 0
    card.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Accent
    stroke.Thickness = 1.2
    stroke.Transparency = 0.32
    stroke.Parent = card

    local glow = Instance.new("Frame")
    glow.BackgroundColor3 = Theme.Accent
    glow.BackgroundTransparency = 0.9
    glow.Size = UDim2.new(1, -30, 0, 60)
    glow.Position = UDim2.fromOffset(15, 12)
    glow.BorderSizePixel = 0
    glow.Parent = card
    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0, 14)
    glowCorner.Parent = glow

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -40, 0, 28)
    label.Position = UDim2.fromOffset(20, 20)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 22
    label.Text = "Frost"
    label.TextColor3 = Theme.TextMain
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = card

    local subLabel = Instance.new("TextLabel")
    subLabel.BackgroundTransparency = 1
    subLabel.Size = UDim2.new(1, -40, 0, 22)
    subLabel.Position = UDim2.fromOffset(20, 52)
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 12
    subLabel.TextColor3 = Theme.TextDim
    subLabel.Text = "Enter your key to continue"
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.Parent = card

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -40, 0, 38)
    box.Position = UDim2.fromOffset(20, 90)
    box.BackgroundColor3 = Theme.Surface
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamBold
    box.TextSize = 15
    box.Text = ""
    box.PlaceholderText = "FREEKEY-XXXX-XXXX"
    box.PlaceholderColor3 = Theme.TextDim
    box.TextColor3 = Theme.TextMain
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = card
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 10)
    boxCorner.Parent = box

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1, -40, 0, 24)
    status.Position = UDim2.fromOffset(20, 136)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.Text = ""
    status.TextColor3 = Theme.TextDim
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = card

    local buttonRow = Instance.new("Frame")
    buttonRow.BackgroundTransparency = 1
    buttonRow.Size = UDim2.new(1, -40, 0, 34)
    buttonRow.Position = UDim2.fromOffset(20, 168)
    buttonRow.Parent = card

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Size = UDim2.new(0.5, -4, 1, 0)
    unlockBtn.BackgroundColor3 = Theme.Accent
    unlockBtn.BorderSizePixel = 0
    unlockBtn.Font = Enum.Font.GothamBold
    unlockBtn.TextSize = 14
    unlockBtn.TextColor3 = Color3.new(1, 1, 1)
    unlockBtn.Text = "Unlock"
    unlockBtn.Parent = buttonRow
    local unlockCorner = Instance.new("UICorner")
    unlockCorner.CornerRadius = UDim.new(0, 9)
    unlockCorner.Parent = unlockBtn

    local retryBtn = Instance.new("TextButton")
    retryBtn.Position = UDim2.new(0.5, 4, 0, 0)
    retryBtn.Size = UDim2.new(0.5, -4, 1, 0)
    retryBtn.BackgroundColor3 = Theme.Surface
    retryBtn.BorderSizePixel = 0
    retryBtn.Font = Enum.Font.Gotham
    retryBtn.TextSize = 13
    retryBtn.TextColor3 = Theme.TextMain
    retryBtn.Text = "Re-check Key"
    retryBtn.Parent = buttonRow
    local retryCorner = Instance.new("UICorner")
    retryCorner.CornerRadius = UDim.new(0, 9)
    retryCorner.Parent = retryBtn

    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Position = UDim2.fromOffset(20, 210)
    getKeyBtn.Size = UDim2.new(1, -40, 0, 32)
    getKeyBtn.BackgroundColor3 = Theme.AccentDark
    getKeyBtn.BorderSizePixel = 0
    getKeyBtn.Font = Enum.Font.GothamSemibold
    getKeyBtn.TextSize = 13
    getKeyBtn.TextColor3 = Color3.new(1, 1, 1)
    getKeyBtn.Text = "Get Key - Copy Discord Invite"
    getKeyBtn.Parent = card
    local getKeyCorner = Instance.new("UICorner")
    getKeyCorner.CornerRadius = UDim.new(0, 9)
    getKeyCorner.Parent = getKeyBtn

    local discordInvite = "https://discord.gg/TWnmPCxxSY"
    getKeyBtn.MouseButton1Click:Connect(function()
        local copied = false
        for _, clipboardName in ipairs({ "setclipboard", "toclipboard" }) do
            local clipboard = getfenv and getfenv()[clipboardName]
            if type(clipboard) == "function" then
                copied = pcall(clipboard, discordInvite)
                if copied then
                    break
                end
            end
        end
        status.TextColor3 = Theme.Success
        if copied then
            status.Text = "Discord invite copied. Paste it into Discord or your browser."
        else
            status.Text = "Discord invite: " .. discordInvite
        end
    end)

    local info = Instance.new("TextLabel")
    info.BackgroundTransparency = 1
    info.Size = UDim2.new(1, 0, 0, 20)
    info.Position = UDim2.fromOffset(0, 258)
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.TextColor3 = Theme.TextDim
    info.Text = "Get the free key with /key in our Discord (role required)"
    info.Parent = card

    local function attempt()
        print("[Frost] Attempting to unlock with current key from GitHub")
        keyState.ServerKey = fetchServerKey()
        if keyState.ServerKey == "" then
            print("[Frost] ERROR: could not fetch key list")
            status.TextColor3 = Theme.Danger
            status.Text = "Could not load the key list from GitHub. Check your internet and retry."
            return
        end
        local entered = normalizeKey(box.Text)
        local expected = normalizeKey(keyState.ServerKey)
        print("[Frost] entered " .. #entered .. " chars, server key " .. #expected .. " chars")
        if entered ~= "" and entered == expected then
            print("[Frost] Key accepted. Opening hub...")
            keyState.Valid = true
            status.TextColor3 = Theme.Success
            status.Text = "Key accepted. Opening hub..."
            waitSafe(0.2)
            local okHub, hubErr = pcall(buildHub)
            if okHub then
                status.Text = "Key accepted. Opening hub..."
                screenGui:Destroy()
            else
                keyState.Valid = false
                status.TextColor3 = Theme.Danger
                status.Text = "Hub error: " .. tostring(hubErr)
                warn("[Frost] Hub failed: " .. tostring(hubErr))
            end
        else
            print("[Frost] Key rejected")
            status.TextColor3 = Theme.Danger
            status.Text = "Invalid key (" .. #entered .. " chars entered). Run /key in our Discord for the current key."
        end
    end

    unlockBtn.MouseButton1Click:Connect(attempt)
    retryBtn.MouseButton1Click:Connect(function()
        status.TextColor3 = Theme.TextDim
        status.Text = "Checking..."
        coroutine.wrap(function()
            waitSafe(0.3)
            attempt()
        end)()
    end)
    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            attempt()
        end
    end)
end

function buildHub()
    print("[Frost] Building hub")
    local supportedGames = {
        {
            Name = "Steal An Egg",
            PlaceId = 107778070777162,
            TabLabel = "Steal An Egg",
            Load = function(hub, tab)
                tab:AddButton("Teleport to Base", function()
                    local char = getCharacter()
                    local root = getRootPart(char)
                    local base = workspace:FindFirstChild("Base") or workspace:FindFirstChild("Baseplate")
                    if base and root then
                        root.CFrame = base.CFrame + Vector3.new(0, 5, 0)
                    end
                end, true)
                tab:AddLabel("Add your Steal An Egg features here.", true)
            end,
        },
        {
            Name = "Slap Battles",
            PlaceId = 6403373529,
            TabLabel = "Slap Battles",
            Load = function(hub, tab)
                tab:AddButton("Teleport to Spawn", function()
                    local char = getCharacter()
                    local root = getRootPart(char)
                    local spawn = workspace:FindFirstChild("Spawns")
                    if spawn then
                        local part = spawn:FindFirstChildWhichIsA("Part") or workspace:FindFirstChildWhichIsA("SpawnLocation")
                        if part and root then
                            root.CFrame = part.CFrame + Vector3.new(0, 5, 0)
                        end
                    end
                end, true)
                tab:AddLabel("Add your Slap Battles features here.", true)
            end,
        },
        {
            Name = "Tower Defense Simulator",
            PlaceId = 3260590327,
            TabLabel = "TDS",
            Load = function(hub, tab)
                tab:AddLabel("Add your TDS features here.", true)
            end,
        },
        {
            Name = "Untitled Boxing Game",
            PlaceId = 4908431598,
            TabLabel = "UBG",
            Load = function(hub, tab)
                tab:AddLabel("Add your UBG features here.", true)
            end,
        },
        {
            Name = "Prison Life",
            PlaceId = 155615604,
            TabLabel = "Prison Life",
            Load = function(hub, tab)
                tab:AddLabel("Add your Prison Life features here.", true)
            end,
        },
    }

    local placeId = tostring(game.PlaceId)
    local detected = nil
    for _, g in ipairs(supportedGames) do
        if tostring(g.PlaceId) == placeId then
            detected = g
            break
        end
    end

    local hub = Lib.CreateWindow({
        Title = "Frost - " .. (detected and detected.Name or "Unknown Game"),
        Size = Vector2.new(560, 400),
    })

    local universal = hub.AddTab("Universal")

    universal:AddToggle("Walkspeed 240", false, function(on)
        local char = getCharacter()
        local hum = getHumanoid(char)
        if hum then
            hum.WalkSpeed = on and 240 or 16
        end
    end)

    universal:AddToggle("Jump Power 100", false, function(on)
        local char = getCharacter()
        local hum = getHumanoid(char)
        if hum then
            hum.JumpPower = on and 100 or 50
            hum.UseJumpPower = true
        end
    end)

    local flyConns = {}
    universal:AddToggle("Fly (WASD + Space / Shift)", false, function(on)
        local char = getCharacter()
        local hum = getHumanoid(char)
        local root = getRootPart(char)
        if not hum or not root then
            return
        end
        if on then
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.zero
            bv.Parent = root
            flyConns.bv = bv
            flyConns.hb = RunService.Heartbeat:Connect(function()
                local camera = workspace.CurrentCamera
                local speed = 50
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    dir = dir + camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    dir = dir - camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    dir = dir - camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    dir = dir + camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    dir = dir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    dir = dir - Vector3.new(0, 1, 0)
                end
                if dir.Magnitude > 0.01 then
                    bv.Velocity = dir.Unit * speed
                else
                    bv.Velocity = Vector3.zero
                end
                hum.PlatformStand = true
                root.AssemblyLinearVelocity = Vector3.zero
            end)
            hum.PlatformStand = true
        else
            if flyConns.hb then
                flyConns.hb:Disconnect()
            end
            if flyConns.bv then
                flyConns.bv:Destroy()
            end
            flyConns = {}
            local root2 = getRootPart(getCharacter())
            if root2 then
                local old = root2:FindFirstChildOfClass("BodyVelocity")
                if old then
                    old:Destroy()
                end
            end
            local ch2 = getCharacter()
            local h2 = getHumanoid(ch2)
            if h2 then
                h2.PlatformStand = false
            end
        end
    end)

    local noclipConn = nil
    universal:AddToggle("NoClip", false, function(on)
        local char = getCharacter()
        if on then
            noclipConn = RunService.Stepped:Connect(function()
                for _, part in ipairs(getCharacter():GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end)
        else
            if noclipConn then
                noclipConn:Disconnect()
                noclipConn = nil
            end
        end
    end)

    universal:AddButton("Teleport to Spawn", function()
        local root = getRootPart(getCharacter())
        local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
        if spawn and root then
            root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
        else
            local char = getCharacter()
            local hum = getHumanoid(char)
            if hum then
                hum.Sit = false
            end
        end
    end)

    universal:AddButton("Rejoin", function()
        local ts = game:GetService("TeleportService")
        local _, code = pcall(function()
            return ts:GetJobId(game.PlaceId)
        end)
        pcall(function()
            ts:Teleport(game.PlaceId, LocalPlayer, nil, code)
        end)
    end, true)

    if detected then
        local gameTab = hub.AddTab(detected.TabLabel)
        detected.Load(hub, gameTab)
    end

    local supported = hub.AddTab("Supported Games")
    supported:AddLabel("Games currently listed in this hub", true)
    for _, g in ipairs(supportedGames) do
        supported:AddLabel(string.format("%s  |  PlaceId %s", g.Name, tostring(g.PlaceId)))
    end
    if not detected then
        local unsupported = hub.AddTab("Unsupported")
        unsupported:AddLabel("This game is not in the supported list yet.", true)
        unsupported:AddLabel("Choose Supported Games to view the current list.", true)
    end

    hub.Select("Universal")
end

local okStart, errStart = pcall(function()
    coroutine.wrap(function()
        pcall(function()
            if setidentity then
                setidentity(8)
            end
        end)
        waitSafe(0.5)
        buildKeyGui()
    end)()
end)
if not okStart then
    warn("[Frost] Failed to start: " .. tostring(errStart))
end