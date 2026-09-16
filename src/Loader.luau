-- Frost loader.
--
-- Paste this single line into your executor:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/src/Loader.luau"))()
--
-- This file is the only thing that is ever pasted. It owns three things:
--   1. the ordered list of executor HTTP implementations (needed before any
--      module can be downloaded, so it cannot live in a module);
--   2. the module registry that `ctx.require("ui/Window")` resolves against;
--   3. the boot screen, which doubles as the error reporter.
--
-- Change the repo/branch below if you fork this.

print("[Frost] Loader started")

local ctx = {
	repo = {
		owner = "Frost-GG-Hud",
		name = "Loader",
		branch = "main",
		sourceRoot = "src",
	},
}

local RAW_PATTERN = "https://raw.githubusercontent.com/%s/%s/%s/%s"
local CDN_PATTERN = "https://cdn.jsdelivr.net/gh/%s/%s@%s/%s"

-- `liveOnly` is used for keys.json. raw.githubusercontent is never cached; the
-- jsDelivr mirror caches for hours, and serving a stale key would lock every
-- user out of the hub until that cache expired.
function ctx.buildUrls(path, liveOnly)
	local repo = ctx.repo
	local urls = { string.format(RAW_PATTERN, repo.owner, repo.name, repo.branch, path) }
	if not liveOnly then
		table.insert(urls, string.format(CDN_PATTERN, repo.owner, repo.name, repo.branch, path))
	end
	return urls
end

--------------------------------------------------------------------- transport

local HttpService = game:GetService("HttpService")

local function unwrap(response)
	if type(response) == "string" then
		return response
	end
	if type(response) == "table" then
		if type(response.Body) == "string" then
			return response.Body
		end
		if type(response.body) == "string" then
			return response.body
		end
	end
	return nil
end

local function looksLikeErrorPage(body)
	if type(body) ~= "string" or #body == 0 then
		return true
	end
	local head = string.lower(string.sub(body, 1, 60))
	return string.find(head, "<!doctype", 1, true) ~= nil
		or string.find(head, "<html", 1, true) ~= nil
		or string.find(head, "404", 1, true) ~= nil
end

local function serviceRequest(url)
	pcall(function()
		HttpService.HttpEnabled = true
	end)
	if not HttpService.HttpEnabled then
		return nil
	end
	return HttpService:GetAsync(url)
end

local function serviceRequestAsync(url)
	pcall(function()
		HttpService.HttpEnabled = true
	end)
	if not HttpService.HttpEnabled then
		return nil
	end
	return unwrap(HttpService:RequestAsync({ Url = url, Method = "GET" }))
end

-- Ordered best-to-worst. Executor globals come first: they work even when the
-- game itself has HTTP requests turned off, which is common.
local methods = {}

if type(game.HttpGet) == "function" then
	table.insert(methods, function(url)
		return game:HttpGet(url)
	end)
end
if type(game.HttpGetAsync) == "function" then
	table.insert(methods, function(url)
		return game:HttpGetAsync(url)
	end)
end
if type(request) == "function" then
	table.insert(methods, function(url)
		return unwrap(request({ Url = url, Method = "GET" }))
	end)
end
if type(http_request) == "function" then
	table.insert(methods, function(url)
		return unwrap(http_request({ Url = url, Method = "GET" }))
	end)
end
if type(syn) == "table" and type(syn.request) == "function" then
	table.insert(methods, function(url)
		return unwrap(syn.request({ Url = url, Method = "GET" }))
	end)
end
if type(http) == "table" and type(http.request) == "function" then
	table.insert(methods, function(url)
		return unwrap(http.request({ Url = url, Method = "GET" }))
	end)
end

table.insert(methods, serviceRequest)
table.insert(methods, serviceRequestAsync)

function ctx.fetch(url)
	for _, method in ipairs(methods) do
		local ok, result = pcall(method, url)
		if ok and not looksLikeErrorPage(result) then
			return result
		end
	end
	return nil
end

------------------------------------------------------------------ module registry

local compile = loadstring or load
local moduleCache = {}

function ctx.require(modulePath)
	local cached = moduleCache[modulePath]
	if cached ~= nil then
		return cached
	end

	local source = nil
	for _, url in ipairs(ctx.buildUrls(ctx.repo.sourceRoot .. "/" .. modulePath .. ".luau", false)) do
		source = ctx.fetch(url)
		if source then
			break
		end
	end

	if not source then
		error("[Frost] Could not download module '" .. modulePath .. "'.", 0)
	end

	local chunk, compileError = compile(source)
	if not chunk then
		error("[Frost] Module '" .. modulePath .. "' has a syntax error: " .. tostring(compileError), 0)
	end

	local ok, value = pcall(chunk, ctx)
	if not ok then
		error("[Frost] Module '" .. modulePath .. "' failed to load: " .. tostring(value), 0)
	end

	moduleCache[modulePath] = value
	return value
end

------------------------------------------------------------------------- boot gui

local boot = Instance.new("ScreenGui")
boot.Name = "FrostBoot"
boot.ResetOnSpawn = false
boot.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
label.Size = UDim2.new(0, 470, 0, 150)
label.Position = UDim2.new(0.5, -235, 0, 28)
label.AnchorPoint = Vector2.new(0.5, 0)
label.BackgroundColor3 = Color3.fromRGB(10, 27, 22)
label.BackgroundTransparency = 0.05
label.BorderSizePixel = 0
label.TextColor3 = Color3.fromRGB(242, 245, 247)
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.TextWrapped = true
label.Text = "Frost\nStarting..."
label.Parent = boot

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = label

local DANGER = Color3.fromRGB(235, 94, 94)
local ACCENT = Color3.fromRGB(108, 211, 169)

local function status(text, color)
	print("[Frost] " .. text)
	label.TextColor3 = color or Color3.fromRGB(242, 245, 247)
	label.Text = "Frost\n" .. text
end

status("Fetching the hub from GitHub...")

local mainSource = nil
for _, url in ipairs(ctx.buildUrls(ctx.repo.sourceRoot .. "/main.luau", false)) do
	status("Trying: " .. url)
	mainSource = ctx.fetch(url)
	if mainSource then
		status("Fetched " .. #mainSource .. " bytes. Compiling...")
		break
	end
end

if not mainSource then
	status("FAILED to download main.luau.\nYour executor cannot reach GitHub.", DANGER)
	return
end

local mainChunk, mainError = compile(mainSource)
if not mainChunk then
	status("Compile error:\n" .. tostring(mainError), DANGER)
	return
end

status("Compiled. Starting the hub...")
if task and task.wait then
	task.wait(0.1)
end

-- ctx is passed as `...`: main.luau (and every module it loads) reads it as its
-- first vararg, which is how dependency injection works across these files.
local ok, runError = pcall(mainChunk, ctx)
if not ok then
	status("Run error:\n" .. tostring(runError), DANGER)
	return
end

boot:Destroy()
print("[Frost] Loader finished - main.luau is in control")
