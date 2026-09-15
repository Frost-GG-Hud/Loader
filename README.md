# Frost

Roblox hub with a key-gated GUI. The key UI pops up first; valid keys unlock a feature hub with Universal features plus per-game features you load from the Information tab. Keys are managed and shown by a Discord bot via `/key`.

## Layout

| Path | Purpose |
| ---- | ------- |
| `bot.py` | Discord bot with role-gated `/key` (view key embed), `/script` (get loader line), and `/setkey` (rotate key) |
| `keys.json` | Single source of truth for the current free key (read by bot and by the hub) |
| `src/main.luau` | Full hub: key prompt GUI, hub window, Universal tab, Information tab (game selector), Steal An Egg features |
| `src/Loader.luau` | Paste this line into your executor |
| `push_to_github.py` | Pushes all local files straight to the GitHub repo via the API |

## 1. Host the script on GitHub

1. Create a GitHub repo (or use the existing `Frost-GG-Hud/Loader`) and push this folder to branch `main`.
2. The public raw URLs used by the hub:
   - `https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/src/main.luau`
   - `https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/keys.json`
3. If you use a different repo/owner/branch, edit `Config` at the top of `src/main.luau` and `GITHUB_REPO`/`GITHUB_BRANCH` in `.env`.
4. Make sure `.env` is NOT pushed (it is in `.gitignore`).

To publish any local change (bot code, keys, the hub script), just run:

```powershell
python push_to_github.py
```

It reads `GITHUB_TOKEN` from `.env` and pushes every tracked file straight to the repo via the GitHub API — no `git` CLI required.

## 2. Run the Discord bot

First time:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Then edit `.env` and paste your bot token into `DISCORD_TOKEN`, then start the bot:

```powershell
python bot.py
```

`.env` notes:

- `DISCORD_TOKEN` — your bot token. Keep it secret. Anyone who sees it can control the bot.
- `ALLOWED_ROLE_ID` — role allowed to run `/key`, `/script`, and `/setkey`.
- `GUILD_ID` — (recommended) server ID so slash commands register instantly.
- `GITHUB_TOKEN` + `GITHUB_REPO`/`GITHUB_BRANCH` — needed so `/setkey` can auto-push the new key to GitHub.

Users with the role run `/key` to get an embed showing the current key (visible to everyone in the channel). `/script` gives the exact loadstring line to paste into an executor. `/setkey <newkey>` rotates the key and pushes it to GitHub.

## 3. In-game

Paste into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/src/Loader.luau"))()
```

Flow: key request GUI appears first -> enter the key from `/key` -> hub opens on the **Information** tab -> click **Load Steal An Egg Features** (or stay on **Universal**). It reads the current key live from GitHub, so rotating a key immediately invalidates old ones.

## Adding games

In `src/main.luau`, inside `buildHub`, find the `supportedGames` table. Add an entry:

```lua
supportedGames["Your Game"] = {
    PlaceId = 123456789, -- from the game page URL
    Features = function(tab)
        tab:AddButton("My Feature", function() print("hi") end)
        tab:AddToggle("My Toggle", false, function(on) end)
    end,
}
```

Then add a button in the Information tab that calls `gameObj.Features(gameTab)` similar to the existing "Load Steal An Egg Features" button.

## Warning

- Never commit `.env` — it contains your bot token and GitHub token.
- This is client-side scripting that violates Roblox ToS; accounts using it can be banned.
- If your token was ever shared (e.g. pasted in a chat), regenerate it immediately in the Discord developer portal / GitHub settings.
