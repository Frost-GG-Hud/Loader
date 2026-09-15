-- Shared configuration for the Frost hub.
-- Every remote URL used at runtime is derived from this table.

local ctx = ...
local repo = ctx.repo or {}

local Config = {
	-- Repo details come from the loader, which is the file people actually paste
	-- and edit. The literals below only apply if main.luau is run on its own.
	RepoOwner = repo.owner or "Frost-GG-Hud",
	RepoName = repo.name or "Loader",
	Branch = repo.branch or "main",
	SourceRoot = repo.sourceRoot or "src",
	KeyFile = "keys.json",
	DiscordInvite = "https://discord.gg/TWnmPCxxSY",
	ToggleKey = Enum.KeyCode.RightShift,
}

local function fallbackUrl(path, useCdn)
	if useCdn then
		return string.format(
			"https://cdn.jsdelivr.net/gh/%s/%s@%s/%s",
			Config.RepoOwner,
			Config.RepoName,
			Config.Branch,
			path
		)
	end
	return string.format(
		"https://raw.githubusercontent.com/%s/%s/%s/%s",
		Config.RepoOwner,
		Config.RepoName,
		Config.Branch,
		path
	)
end

-- URL building lives in the loader so the host order is defined exactly once.
-- These fallbacks are only reached when main.luau runs without the loader.
--
-- Note the ordering: raw.githubusercontent is always first because it is never
-- cached, and the free key rotates. Serving a stale CDN copy would lock every
-- user out of the hub until the cache expired.
function Config.assetUrls(path)
	if ctx.buildUrls then
		return ctx.buildUrls(path, false)
	end
	return { fallbackUrl(path, false), fallbackUrl(path, true) }
end

-- Live data (the key file) must never come from a CDN mirror.
function Config.liveUrls(path)
	if ctx.buildUrls then
		return ctx.buildUrls(path, true)
	end
	return { fallbackUrl(path, false) }
end

function Config.moduleUrls(modulePath)
	return Config.assetUrls(Config.SourceRoot .. "/" .. modulePath .. ".luau")
end

function Config.sourceUrls()
	return Config.assetUrls(Config.SourceRoot .. "/main.luau")
end

return Config
