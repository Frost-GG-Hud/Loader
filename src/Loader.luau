print("[Frost] Loader started")

local boot = Instance.new("ScreenGui")
boot.Name = "FrostBoot"
boot.ResetOnSpawn = false
if gethui then
    pcall(function()
        boot.Parent = gethui()
    end)
end
if not boot.Parent then
    pcall(function()
        boot.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 15)
    end)
end

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 460, 0, 140)
label.Position = UDim2.new(0.5, -230, 0, 30)
label.AnchorPoint = Vector2.new(0.5, 0)
label.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
label.BackgroundTransparency = 0.05
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(240, 240, 245)
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.TextWrapped = true
label.Text = "Frost\nLoading script..."
label.Parent = boot

local function status(text, color)
    print("[Frost] " .. text)
    label.TextColor3 = color or Color3.fromRGB(240, 240, 245)
    label.Text = "Frost - v2\n" .. text
end

status("Trying to reach GitHub...")

local HOSTS = {
    "https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/src/main.luau",
    "https://cdn.jsdelivr.net/gh/Frost-GG-Hud/Loader@main/src/main.luau",
}

local function fetch(url)
    local svc = game:GetService("HttpService")
    pcall(function()
        svc.HttpEnabled = true
    end)
    local attempts = {
        function()
            return svc:HttpGet(url)
        end,
        function()
            return svc:HttpGetAsync(url)
        end,
        function()
            return game:HttpGet(url)
        end,
        function()
            return game:HttpGetAsync(url)
        end,
        function()
            return request({ Url = url, Method = "GET" }).Body
        end,
        function()
            return http_request({ Url = url, Method = "GET" }).Body
        end,
        function()
            return syn.request({ Url = url, Method = "GET" }).Body
        end,
    }
    for _, fn in ipairs(attempts) do
        local ok, res = pcall(fn)
        if ok and typeof(res) == "string" and #res > 50 then
            return res
        end
    end
    return nil
end

local raw = nil
for _, url in ipairs(HOSTS) do
    status("Trying: " .. url)
    raw = fetch(url)
    if raw then
        status("Fetched " .. #raw .. " chars. Compiling...")
        break
    end
end

if not raw then
    status("FAILED to fetch the script.\nYour HTTP access to GitHub/jsDelivr is blocked.", Color3.fromRGB(235, 90, 90))
    return
end

local chunk, loadErr = loadstring(raw)
if not chunk then
    status("Compile error:\n" .. tostring(loadErr), Color3.fromRGB(235, 90, 90))
    return
end
status("Compiled. Running...")

local ok, runErr = pcall(chunk)
if not ok then
    status("Run error:\n" .. tostring(runErr), Color3.fromRGB(235, 90, 90))
    return
end

boot:Destroy()
print("[Frost] Loader done - main.luau took over the screen")