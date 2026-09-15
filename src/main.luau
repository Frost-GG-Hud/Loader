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
    return LocalPlayer.Character or (LocalPlayer.CharacterAdded and LocalPlayer.CharacterAdded:Wait(), LocalPlayer.Character)
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
    Background = Color3.fromRGB(18, 18, 24),
    Sidebar = Color3.fromRGB(24, 24, 32),
    Card = Color3.fromRGB(31, 31, 42),
    Accent = Color3.fromRGB(94, 129, 255),
    AccentDark = Color3.fromRGB(70, 100, 230),
    TextMain = Color3.fromRGB(240, 240, 245),
    TextDim = Color3.fromRGB(150, 150, 165),
    Danger = Color3.fromRGB(235, 90, 90),
    Success = Color3.fromRGB(90, 200, 130),
}

local Lib = {}

function Lib.CreateWindow(opts)
    opts = opts or {}
    local title = opts.Title or "Frost"
    local size = opts.Size or Vector2.new(560, 400)
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

    local window = Instance.new("Frame")
    window.Name = "Window"
    window.Size = UDim2.fromOffset(size.X, size.Y)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.BackgroundColor3 = Theme.Background
    window.BorderSizePixel = 0
    window.Parent = screenGui

    local winCorner = Instance.new("UICorner")
    winCorner.CornerRadius = UDim.new(0, 12)
    winCorner.Parent = window

    local winStroke = Instance.new("UIStroke")
    winStroke.Color = accent
    winStroke.Thickness = 1.5
    winStroke.Transparency = 0.4
    winStroke.Parent = window

    local winShadow = Instance.new("ImageLabel")
    winShadow.Name = "Shadow"
    winShadow.BackgroundTransparency = 1
    winShadow.Size = UDim2.new(1, 24, 1, 24)
    winShadow.Position = UDim2.fromOffset(-12, -12)
    winShadow.Image = "rbxassetid://5028857084"
    winShadow.ImageColor3 = Color3.new(0, 0, 0)
    winShadow.ImageTransparency = 0.6
    winShadow.ScaleType = Enum.ScaleType.Slice
    winShadow.SliceCenter = Rect.new(24, 24, 276, 276)
    winShadow.ZIndex = 0
    winShadow.Parent = window

    local logoCircle = drawCircle("_Logo", window, 10, accent)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(0.6, -40, 0, 32)
    titleLabel.Position = UDim2.fromOffset(28, 0)
    titleLabel.Text = title
    titleLabel.TextColor3 = Theme.TextMain
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 17
    titleLabel.Parent = window

    local titlebar = Instance.new("TextButton")
    titlebar.Name = "_DragBar"
    titlebar.BackgroundTransparency = 1
    titlebar.Size = UDim2.new(1, 0, 0, 36)
    titlebar.Text = ""
    titlebar.ZIndex = 50
    titlebar.Parent = window

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "Close"
    closeButton.Size = UDim2.fromOffset(26, 26)
    closeButton.Position = UDim2.new(1, -32, 0, 5)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = "x"
    closeButton.TextColor3 = Theme.TextDim
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.ZIndex = 60
    closeButton.Parent = window
    closeButton.MouseButton1Click:Connect(function()
        window.Visible = not window.Visible
    end)

    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 150, 1, -36)
    sidebar.Position = UDim2.fromOffset(0, 36)
    sidebar.BackgroundColor3 = Theme.Sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = window

    local sideCorner = Instance.new("UICorner")
    sideCorner.CornerRadius = UDim.new(0, 12)
    sideCorner.Parent = sidebar

    local tabList = Instance.new("ScrollingFrame")
    tabList.Name = "Tabs"
    tabList.Size = UDim2.new(1, 0, 1, 0)
    tabList.BackgroundTransparency = 1
    tabList.BorderSizePixel = 0
    tabList.ScrollBarThickness = 0
    tabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabList.Parent = sidebar

    local contentArea = Instance.new("Frame")
    contentArea.Name = "Content"
    contentArea.Size = UDim2.new(1, -170, 1, -56)
    contentArea.Position = UDim2.fromOffset(160, 48)
    contentArea.BackgroundTransparency = 1
    contentArea.ClipsDescendants = true
    contentArea.Parent = window

    local contentBG = Instance.new("Frame")
    contentBG.BackgroundColor3 = Theme.Card
    contentBG.BorderSizePixel = 0
    contentBG.Size = UDim2.new(1, 0, 1, 0)
    contentBG.Parent = contentArea
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 12)
    bgCorner.Parent = contentBG

    local dragObject
    titlebar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragObject = input
        end
    end)
    titlebar.InputEnded:Connect(function(input)
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
        btn.Size = UDim2.new(1, 0, 0, 32)
        btn.Position = UDim2.fromOffset(0, (tabIndex - 1) * 34)
        btn.BackgroundColor3 = Theme.Sidebar
        btn.BorderSizePixel = 0
        btn.Text = name
        btn.TextColor3 = Theme.TextDim
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 14
        btn.ZIndex = 5
        btn.Parent = tabList

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

        local spacing = 0
        local tab = {
            _btn = btn,
            _page = page,
            _accent = accent,
            AddLabel = function(self, text, dim)
                spacing = spacing + 4
                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Size = UDim2.new(1, -20, 0, 20)
                lbl.Position = UDim2.fromOffset(10, spacing)
                lbl.Text = text
                lbl.TextColor3 = dim and Theme.TextDim or Theme.TextMain
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 13
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = page
                spacing = spacing + 20
            end,
            AddButton = function(self, text, callback, danger)
                spacing = spacing + 6
                local card = Instance.new("Frame")
                card.BackgroundColor3 = Theme.Card
                card.BorderSizePixel = 0
                card.Size = UDim2.new(1, -32, 0, 36)
                card.Position = UDim2.fromOffset(16, spacing)
                card.Parent = page
                local cardCorner = Instance.new("UICorner")
                cardCorner.CornerRadius = UDim.new(0, 8)
                cardCorner.Parent = card
                local b = Instance.new("TextButton")
                b.Text = text
                b.BackgroundTransparency = 1
                b.Size = UDim2.new(1, 0, 1, 0)
                b.Font = Enum.Font.GothamBold
                b.TextSize = 14
                b.TextColor3 = danger and Theme.Danger or Theme.TextMain
                b.Parent = card
                local fill = Instance.new("Frame")
                fill.BackgroundColor3 = danger and Theme.Danger or accent
                fill.BorderSizePixel = 0
                fill.Size = UDim2.new(1, 0, 0, 3)
                fill.Position = UDim2.new(0, 0, 1, -3)
                fill.Visible = false
                fill.Parent = card
                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(0, 4)
                fillCorner.Parent = fill
                b.MouseEnter:Connect(function()
                    TweenService:Create(fill, TweenInfo.new(0.12), { Visible = true }):Play()
                end)
                b.MouseLeave:Connect(function()
                    TweenService:Create(fill, TweenInfo.new(0.12), { Visible = false }):Play()
                end)
                b.MouseButton1Click:Connect(function()
                    if callback then
                        pcall(function()
                            callback()
                        end)
                    end
                end)
                spacing = spacing + 42
            end,
            AddToggle = function(self, text, default, onChange)
                spacing = spacing + 6
                local card = Instance.new("Frame")
                card.BackgroundColor3 = Theme.Card
                card.BorderSizePixel = 0
                card.Size = UDim2.new(1, -32, 0, 36)
                card.Position = UDim2.fromOffset(16, spacing)
                card.Parent = page
                local cardCorner = Instance.new("UICorner")
                cardCorner.CornerRadius = UDim.new(0, 8)
                cardCorner.Parent = card

                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Size = UDim2.new(1, -50, 1, 0)
                lbl.Position = UDim2.fromOffset(12, 0)
                lbl.Text = text
                lbl.TextColor3 = Theme.TextMain
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 14
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = card

                local value = default == true
                local toggle = Instance.new("Frame")
                toggle.Size = UDim2.fromOffset(34, 18)
                toggle.Position = UDim2.new(1, -46, 0.5, -9)
                toggle.BackgroundColor3 = Theme.Background
                toggle.BorderSizePixel = 0
                toggle.Parent = card
                local toggleCorner = Instance.new("UICorner")
                toggleCorner.CornerRadius = UDim.new(1, 0)
                toggleCorner.Parent = toggle

                local knob = Instance.new("Frame")
                knob.Size = UDim2.fromOffset(14, 14)
                knob.Position = UDim2.fromOffset(2, 2)
                knob.BackgroundColor3 = Theme.TextDim
                knob.BorderSizePixel = 0
                knob.Parent = toggle
                local knobCorner = Instance.new("UICorner")
                knobCorner.CornerRadius = UDim.new(1, 0)
                knobCorner.Parent = knob

                local function apply()
                    TweenService:Create(toggle, TweenInfo.new(0.15), { BackgroundColor3 = value and accent or Theme.Background }):Play()
                    TweenService:Create(knob, TweenInfo.new(0.15), {
                        Position = value and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2),
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
                spacing = spacing + 42
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
                spacing = spacing + 6
                local card = Instance.new("Frame")
                card.BackgroundColor3 = Theme.Card
                card.BorderSizePixel = 0
                card.Size = UDim2.new(1, -32, 0, 44)
                card.Position = UDim2.fromOffset(16, spacing)
                card.Parent = page
                local cardCorner = Instance.new("UICorner")
                cardCorner.CornerRadius = UDim.new(0, 8)
                cardCorner.Parent = card

                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Size = UDim2.new(1, -20, 0, 18)
                lbl.Position = UDim2.fromOffset(12, 2)
                lbl.Text = text
                lbl.TextColor3 = Theme.TextMain
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 13
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.Parent = card

                local valLabel = Instance.new("TextLabel")
                valLabel.BackgroundTransparency = 1
                valLabel.Size = UDim2.new(0, 50, 0, 18)
                valLabel.Position = UDim2.new(1, -60, 0, 2)
                valLabel.Text = tostring(default)
                valLabel.TextColor3 = accent
                valLabel.Font = Enum.Font.GothamBold
                valLabel.TextSize = 13
                valLabel.TextXAlignment = Enum.TextXAlignment.Right
                valLabel.Parent = card

                local track = Instance.new("Frame")
                track.Size = UDim2.new(1, -24, 0, 4)
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
                grab.Size = UDim2.new(0, 40, 0, 20)
                grab.Position = UDim2.new(0, -20, 1, -12)
                grab.Position = UDim2.fromOffset(-20, -8)
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
                spacing = spacing + 50
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
            t._btn.BackgroundColor3 = active and accent or Theme.Sidebar
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

local function buildKeyGui()
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
    dim.BackgroundTransparency = 0.55
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.Parent = screenGui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(380, 250)
    card.BackgroundColor3 = Theme.Background
    card.BorderSizePixel = 0
    card.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Accent
    stroke.Thickness = 1.5
    stroke.Transparency = 0.35
    stroke.Parent = card

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 40)
    label.Position = UDim2.fromOffset(0, 14)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 20
    label.Text = "Frost"
    label.TextColor3 = Theme.TextMain
    label.Parent = card

    local subLabel = Instance.new("TextLabel")
    subLabel.BackgroundTransparency = 1
    subLabel.Size = UDim2.new(1, 0, 0, 34)
    subLabel.Position = UDim2.fromOffset(0, 54)
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 13
    subLabel.TextColor3 = Theme.TextDim
    subLabel.Text = "Enter your key to continue"
    subLabel.Parent = card

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -60, 0, 36)
    box.Position = UDim2.fromOffset(30, 98)
    box.BackgroundColor3 = Theme.Card
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamBold
    box.TextSize = 16
    box.Text = ""
    box.PlaceholderText = "FREEKEY-XXXX-XXXX"
    box.PlaceholderColor3 = Theme.TextDim
    box.TextColor3 = Theme.TextMain
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = card
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 8)
    boxCorner.Parent = box

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1, -40, 0, 30)
    status.Position = UDim2.fromOffset(20, 140)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.Text = ""
    status.TextColor3 = Theme.TextDim
    status.Parent = card

    local buttonRow = Instance.new("Frame")
    buttonRow.BackgroundTransparency = 1
    buttonRow.Size = UDim2.new(1, -30, 0, 36)
    buttonRow.Position = UDim2.fromOffset(15, 178)
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
    unlockCorner.CornerRadius = UDim.new(0, 8)
    unlockCorner.Parent = unlockBtn

    local retryBtn = Instance.new("TextButton")
    retryBtn.Position = UDim2.new(0.5, 4, 0, 0)
    retryBtn.Size = UDim2.new(0.5, -4, 1, 0)
    retryBtn.BackgroundColor3 = Theme.Card
    retryBtn.BorderSizePixel = 0
    retryBtn.Font = Enum.Font.Gotham
    retryBtn.TextSize = 14
    retryBtn.TextColor3 = Theme.TextMain
    retryBtn.Text = "Re-check Key"
    retryBtn.Parent = buttonRow
    local retryCorner = Instance.new("UICorner")
    retryCorner.CornerRadius = UDim.new(0, 8)
    retryCorner.Parent = retryBtn

    local info = Instance.new("TextLabel")
    info.BackgroundTransparency = 1
    info.Size = UDim2.new(1, 0, 0, 20)
    info.Position = UDim2.fromOffset(0, 220)
    info.Font = Enum.Font.Gotham
    info.TextSize = 11
    info.TextColor3 = Theme.TextDim
    info.Text = "Get the free key with /key in our Discord (role required)"
    info.Parent = card

    local function attempt()
        keyState.ServerKey = fetchServerKey()
        if keyState.ServerKey == "" then
            status.TextColor3 = Theme.Danger
            status.Text = "Could not load the key list from GitHub. Check your internet and retry."
            return
        end
        local entered = normalizeKey(box.Text)
        local expected = normalizeKey(keyState.ServerKey)
        if entered ~= "" and entered == expected then
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

local function buildHub()
    local supportedGames = {
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
    else
        local unsupported = hub.AddTab("Unsupported")
        unsupported:AddLabel("This game is not in the supported list yet.", true)
        unsupported:AddLabel("Edit the supportedGames table in src/main.luau to add it.", true)
        for _, g in ipairs(supportedGames) do
            unsupported:AddLabel(string.format("  - %s (PlaceId %s)", g.Name, tostring(g.PlaceId)), true)
        end
    end

    hub.Select("Universal")
end

local okStart, errStart = pcall(function()
    coroutine.wrap(function()
        pcall(function()
            setidentity and setidentity(8)
        end)
        waitSafe(0.5)
        buildKeyGui()
    end)()
end)
if not okStart then
    warn("[Frost] Failed to start: " .. tostring(errStart))
end