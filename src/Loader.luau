print("[Frost] Loader started")

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
local firstErr = nil
for _, url in ipairs(HOSTS) do
    print("[Frost] Trying " .. url)
    raw = fetch(url)
    if raw then
        print("[Frost] Fetched " .. #raw .. " chars from " .. url)
        break
    end
end

if not raw then
    warn("[Frost] COULD NOT FETCH the script from any URL. This environment cannot do HTTP.")
    return
end

local chunk, loadErr = loadstring(raw)
if not chunk then
    warn("[Frost] Script failed to compile: " .. tostring(loadErr))
    return
end
print("[Frost] Compiled. Running main.luau...")

local ok, runErr = pcall(chunk)
if not ok then
    warn("[Frost] Script failed to run: " .. tostring(runErr))
end
print("[Frost] Loader done")