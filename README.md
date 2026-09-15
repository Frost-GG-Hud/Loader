# Frost

Roblox hub with a key-gated GUI. The key UI pops up first; valid keys unlock a feature hub that auto-detects the current game. Keys are managed and shown by a Discord bot via `/key`.

## Layout

| Path | Purpose |
| ---- | ------- |
| `bot.py` | Discord bot with role-gated `/key` (view key embed) and `/setkey` (rotate key) |
| `keys.json` | Single source of truth for the current free key (read by bot AND by the hub) |
| `src/main.luau` | Full hub: key prompt GUI, hub window, game auto-detect, universal features |
| `src/Loader.luau` | Paste this line into your executor |
| `server.py` | Optional tiny web server that serves `/api/script` + `keys.json` from your own domain (no GitHub needed) |

## 1. Host the script

### Option A: your own website (no GitHub needed)

1. Deploy this folder to **Render**, **Railway**, or **Glitch** (the free tier is enough).
   - Render: sign in, New Web Service, connect the repo or drop the folder; `render.yaml` sets it up automatically.
   - Or run `python server.py` locally and expose it with `cloudflared tunnel`.
2. The loadstring then becomes:
   ```lua
   loadstring(game:HttpGet("https://YOUR-SITE.onrender.com/api/script"))()
   ```
3. In `.env` set `SITE_URL` to your domain and `SITE_ADMIN_TOKEN` to any long random value.
   `/setkey` then pushes the new key straight to the site; the hub picks it up live.

### Option B: GitHub raw links (needs a working GitHub account)

1. Create a GitHub repo, push this folder to branch `main`.
2. The public raw URLs used by the hub:
   - `https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/src/main.luau`
   - `https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/keys.json`
3. If you picked a different repo/owner/branch, edit `Config` at the top of `src/main.luau` and `GITHUB_REPO`/`GITHUB_BRANCH` in `.env`.
4. Make sure `.env` is NOT pushed (it is in `.gitignore`).

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
- `ALLOWED_ROLE_ID` — role allowed to run `/key` and `/setkey`.
- `GUILD_ID` — (recommended) server ID so slash commands register instantly.
- `SITE_URL` + `SITE_ADMIN_TOKEN` — optional. When set, `/script` prints the short `loadstring(game:HttpGet("<SITE_URL>/api/script"))()` line, and `/setkey` pushes the new key straight to the site so the hub stays live instantly.
- `GITHUB_TOKEN` + `GITHUB_REPO`/`GITHUB_BRANCH` — optional (only for the GitHub raw links flow).

Users with the role run `/key` to get an embed showing the current key (visible to everyone in the channel). `/setkey <newkey>` rotates it.

## 3. In-game

Paste into your executor (pick whichever path you set up above):

**Website (recommended if you have no GitHub):**
```lua
loadstring(game:HttpGet("https://YOUR-SITE.onrender.com/api/script"))()
```

**GitHub raw:**
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Frost-GG-Hud/Loader/main/src/Loader.luau"))()
```

Flow: key request GUI appears first -> enter the key from `/key` -> hub opens. It reads the current key live (from the site or GitHub), so rotating a key immediately invalidates old ones.

## Adding games

In `src/main.luau`, inside `buildHub`, find the `supportedGames` table. Add an entry:

```lua
{
    Name = "Your Game",
    PlaceId = 123456789,           -- from the game page URL
    TabLabel = "Tab short name",
    Load = function(hub, tab)
        tab:AddButton("My Feature", function() print("hi") end)
        tab:AddToggle("My Toggle", false, function(on) end)
    end,
},
```

When a player joins that game the hub title shows the game name and loads its tab. Unknown games get an "Unsupported" tab listing all supported PlaceIds.

## Warning

- Never commit `.env` — it contains your bot token.
- This is client-side scripting that violates Roblox ToS; accounts using it can be banned.
- If your token was ever shared (e.g. pasted in a chat), regenerate it immediately in the Discord developer portal.