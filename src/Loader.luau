-- Point this at your site (free host like Render):
--   local URL = "https://frost.onrender.com/api/script"
-- Or skip this file entirely and paste the one-liner:
--   loadstring(game:HttpGet("https://frost.onrender.com/api/script"))()
local URL = "https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/src/main.luau"

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

local raw = fetch(URL)
if not raw then
    warn("[Frost] Could not fetch the script. Check internet + that the repo is public.")
    return
end

local chunk, loadErr = loadstring(raw)
if not chunk then
    warn("[Frost] Script failed to compile: " .. tostring(loadErr))
    return
end

local ok, runErr = pcall(chunk)
if not ok then
    warn("[Frost] Script failed to run: " .. tostring(runErr))
end