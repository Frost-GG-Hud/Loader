-- Executor-safe HTTP helpers.
--
-- The original hub called `HttpService:HttpGet(...)`. That method does not exist:
-- HttpService exposes GetAsync/RequestAsync, and `HttpGet` only exists as a
-- function injected onto `game` by executors. The old code "worked" only because
-- its pcall fell through to `game:HttpGet`, which is likewise absent on a
-- locked-down executor - so a blocked executor produced a hub that could never
-- read its own key file.
--
-- The ordered list of real implementations lives in the loader (`ctx.fetch`),
-- because the loader needs it to download this module in the first place. This
-- module only adds URL fallback, validation and JSON on top of it.

local ctx = ...
local Config = ctx.require("core/Config")

local HttpService = game:GetService("HttpService")

local function looksLikeErrorPage(body)
	if type(body) ~= "string" or #body == 0 then
		return true
	end
	local head = string.lower(string.sub(body, 1, 40))
	return string.find(head, "<!doctype", 1, true) ~= nil
		or string.find(head, "<html", 1, true) ~= nil
end

-- Only used if this module is somehow evaluated without the loader.
local function fallbackTransport(url)
	if type(game.HttpGet) == "function" then
		local ok, body = pcall(function()
			return game:HttpGet(url)
		end)
		if ok and type(body) == "string" and #body > 0 then
			return body
		end
	end

	pcall(function()
		HttpService.HttpEnabled = true
	end)
	if HttpService.HttpEnabled then
		local ok, body = pcall(function()
			return HttpService:GetAsync(url)
		end)
		if ok and type(body) == "string" and #body > 0 then
			return body
		end
	end
	return nil
end

local transport = ctx.fetch or fallbackTransport

local Http = {}

function Http.rawGet(url)
	local body = transport(url)
	if looksLikeErrorPage(body) then
		return nil
	end
	return body
end

-- Accepts a single URL or a list of fallback URLs.
function Http.get(urls)
	if type(urls) == "string" then
		return Http.rawGet(urls)
	end
	for _, url in ipairs(urls) do
		local body = Http.rawGet(url)
		if body then
			return body
		end
	end
	return nil
end

-- Static assets (modules, the loader) may come from either mirror.
function Http.getAsset(assetPath)
	return Http.get(Config.assetUrls(assetPath))
end

-- Live data such as keys.json must only ever come from the uncached raw host.
function Http.getLive(assetPath)
	return Http.get(Config.liveUrls(assetPath))
end

function Http.getModule(modulePath)
	return Http.get(Config.moduleUrls(modulePath))
end

function Http.decodeJson(text)
	if type(text) ~= "string" or #text == 0 then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(text)
	end)
	if ok then
		return decoded
	end
	return nil
end

-- Returns the current key, or nil when GitHub could not be reached (which is a
-- different failure from "the key was wrong" and is reported differently).
function Http.getLiveKey(keyFileName)
	local decoded = Http.decodeJson(Http.getLive(keyFileName))
	if decoded and type(decoded.current) == "string" and #decoded.current > 0 then
		return decoded.current
	end
	return nil
end

return Http
