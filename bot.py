import json
import os
import base64

import discord
from discord import app_commands
from discord.ext import commands
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

TOKEN = os.getenv("DISCORD_TOKEN", "")
ALLOWED_ROLE_ID = int(os.getenv("ALLOWED_ROLE_ID", "1549392560256974939"))
GUILD_ID = os.getenv("GUILD_ID", "")
REPO_PATH = os.path.join(BASE_DIR, "keys.json")
TICKETS_CHANNEL_ID = 1549104953463803934
FROST_EMOJI = "<:frost:1549461399065993226>"

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")
GITHUB_REPO = os.getenv("GITHUB_REPO", "Frost-GG-Hud/Loader")
GITHUB_BRANCH = os.getenv("GITHUB_BRANCH", "main")

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="!", intents=intents)
tree = bot.tree


def load_key() -> str:
    try:
        with open(REPO_PATH, "r", encoding="utf-8") as f:
            return json.load(f).get("current", "")
    except (OSError, json.JSONDecodeError):
        return ""


def save_key(key: str):
    with open(REPO_PATH, "w", encoding="utf-8") as f:
        json.dump({"current": key}, f, indent=2)
        f.write("\n")


def github_raw_url(path: str) -> str:
    repo = GITHUB_REPO.strip("/")
    branch = GITHUB_BRANCH.strip("/")
    if not repo:
        repo = "Frost-GG-Hud/Loader"
    if not branch:
        branch = "main"
    return f"https://raw.githubusercontent.com/{repo}/{branch}/{path.lstrip('/')}"


async def has_permission(interaction: discord.Interaction) -> bool:
    return any(role.id == ALLOWED_ROLE_ID for role in interaction.user.roles)


def not_allowed_embed() -> discord.Embed:
    return discord.Embed(
        title="Access Denied",
        description="You do not have the required role to use this command.",
        color=discord.Color.red(),
    )


@tree.command(name="key", description="View the current working free key")
async def key_command(interaction: discord.Interaction):
    current = load_key()
    embed = discord.Embed(
        title="\U0001F511 Current Working Key",
        description=f"```\n{current}\n```",
        color=discord.Color.from_rgb(0, 215, 255),
    )
    embed.set_footer(text="Copy this key and enter it in the Frost Hub prompt.")
    await interaction.response.send_message(embed=embed)


@tree.command(name="info", description="Get the Frost script loader and current key")
@app_commands.describe(channel="Specific channel to send the info to (optional)")
async def info_command(interaction: discord.Interaction, channel: discord.TextChannel = None):
    current = load_key()
    script_url = github_raw_url("src/Loader.luau")
    loader = f'loadstring(game:HttpGet("{script_url}"))()'

    description = (
        f"**Script:**\n```lua\n{loader}\n```\n"
        f"**Key:**\n```\n{current}\n```\n"
        f"If you have any questions, please open a support ticket in <#{TICKETS_CHANNEL_ID}>."
    )

    embed = discord.Embed(
        title=f"{FROST_EMOJI} Frost Hub",
        description=description,
        color=discord.Color.from_rgb(46, 204, 113),
    )

    if channel:
        try:
            await channel.send(embed=embed)
            await interaction.response.send_message(f"Sent the Frost Hub info to {channel.mention}!", ephemeral=True)
        except Exception as e:
            await interaction.response.send_message(f"Could not send to {channel.mention}: {e}", ephemeral=True)
    else:
        await interaction.response.send_message(embed=embed)


@tree.command(name="script", description="Get the Frost loader script")
async def script_command(interaction: discord.Interaction):
    script_url = github_raw_url("src/Loader.luau")
    loader = f'loadstring(game:HttpGet("{script_url}"))()'
    embed = discord.Embed(
        title=f"{FROST_EMOJI} Frost Loader Script",
        description=f"Paste this line into your Roblox executor:\n\n```lua\n{loader}\n```",
        color=discord.Color.from_rgb(0, 215, 255),
    )
    embed.set_footer(text=f"Questions? Open a ticket in #{TICKETS_CHANNEL_ID}")
    await interaction.response.send_message(embed=embed)


@tree.command(name="setkey", description="Update the current working free key (staff only)")
async def setkey_command(interaction: discord.Interaction, key: str):
    if not await has_permission(interaction):
        await interaction.response.send_message(embed=not_allowed_embed(), ephemeral=True)
        return

    save_key(key)
    pushed_to_github = False

    if GITHUB_TOKEN:
        try:
            import requests

            headers = {
                "Authorization": f"Bearer {GITHUB_TOKEN}",
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
            }
            url = f"https://api.github.com/repos/{GITHUB_REPO}/contents/keys.json"
            r = requests.get(url, headers=headers, timeout=30)
            r.raise_for_status()
            existing = r.json()
            sha = existing.get("sha")
            content = base64.b64encode(
                (json.dumps({"current": key}, indent=2) + "\n").encode("utf-8")
            ).decode("utf-8")
            payload = {"message": f"Update free key to {key}", "content": content, "branch": GITHUB_BRANCH}
            if sha:
                payload["sha"] = sha
            r = requests.put(url, headers=headers, json=payload, timeout=60)
            if r.status_code not in (200, 201):
                raise RuntimeError(f"GitHub API {r.status_code}: {r.text[:200]}")
            pushed_to_github = True
        except Exception:
            pass

    if pushed_to_github:
        embed = discord.Embed(
            title="\U00002705 Key Published",
            description=f"New key saved and pushed to GitHub so the hub stays in sync:\n\n```\n{key}\n```",
            color=discord.Color.green(),
        )
    else:
        embed = discord.Embed(
            title="\U000026A0 Key Saved Locally",
            description=f"Set `GITHUB_TOKEN` in `.env` to push it live automatically.\n```\n{key}\n```\nRun `python push_to_github.py` manually to publish it.",
            color=discord.Color.orange(),
        )

    await interaction.response.send_message(embed=embed)


@bot.event
async def on_ready():
    print(f"We have logged in as {bot.user} (ID: {bot.user.id})")
    try:
        if GUILD_ID:
            guild = discord.Object(id=int(GUILD_ID))
            synced = await tree.sync(guild=guild)
        else:
            synced = await tree.sync()
        print(f"Synced {len(synced)} command(s)")
    except Exception as e:
        print(f"Failed to sync commands: {e}")


if __name__ == "__main__":
    if not TOKEN:
        raise SystemExit("DISCORD_TOKEN is missing. Copy .env.example to .env and fill it in.")
    if not ALLOWED_ROLE_ID:
        raise SystemExit("ALLOWED_ROLE_ID is missing in .env")
    bot.run(TOKEN)