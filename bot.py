import base64
import json
import os

import discord
from discord import app_commands
from discord.ext import commands
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

TOKEN = os.getenv("DISCORD_TOKEN", "")
ALLOWED_ROLE_ID_STR = os.getenv("ALLOWED_ROLE_ID", "1549392560256974939")
ALLOWED_ROLE_ID = int(ALLOWED_ROLE_ID_STR) if ALLOWED_ROLE_ID_STR.isdigit() else 0
GUILD_ID = os.getenv("GUILD_ID", "")
REPO_PATH = os.path.join(BASE_DIR, "keys.json")

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
    repo = GITHUB_REPO.strip("/") or "Frost-GG-Hud/Loader"
    branch = GITHUB_BRANCH.strip("/") or "main"
    return f"https://raw.githubusercontent.com/{repo}/{branch}/{path.lstrip('/')}"


async def has_permission(interaction: discord.Interaction) -> bool:
    if not isinstance(interaction.user, discord.Member):
        return False
    if interaction.user.guild_permissions.administrator:
        return True
    if ALLOWED_ROLE_ID and any(role.id == ALLOWED_ROLE_ID for role in interaction.user.roles):
        return True
    return False


def not_allowed_embed() -> discord.Embed:
    return discord.Embed(
        title="Access Denied",
        description="You do not have the required staff permissions to use this command.",
        color=discord.Color.from_rgb(235, 35, 45),
    )


@tree.command(name="key", description="Get the working Frost Steal an Egg key and loader script")
async def key_command(interaction: discord.Interaction):
    current = load_key()
    script_url = github_raw_url("src/Loader.luau")
    loader = f'loadstring(game:HttpGet("{script_url}"))()'

    embed = discord.Embed(
        title="🔑 Frost Steal an Egg — Current Working Key",
        description=(
            f"**Current Free Key:**\n```\n{current}\n```\n"
            f"**Executor Loader Script:**\n```lua\n{loader}\n```\n"
            "Paste the script into your Roblox executor and enter the key above to unlock the hub!"
        ),
        color=discord.Color.from_rgb(235, 35, 45),
    )
    embed.set_footer(text="Frost Steel a Egg V4.6")
    await interaction.response.send_message(embed=embed)


@tree.command(name="setkey", description="Update the current working key and push to GitHub (staff only)")
@app_commands.describe(key="The new key string for users to unlock the script")
async def setkey_command(interaction: discord.Interaction, key: str):
    key = key.strip()
    if not key:
        await interaction.response.send_message("Key cannot be empty.", ephemeral=True)
        return

    if not await has_permission(interaction):
        await interaction.response.send_message(embed=not_allowed_embed(), ephemeral=True)
        return

    save_key(key)
    pushed_to_github = False
    github_error = ""

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
            sha = None
            if r.status_code == 200:
                sha = r.json().get("sha")

            content = base64.b64encode(
                (json.dumps({"current": key}, indent=2) + "\n").encode("utf-8")
            ).decode("utf-8")
            payload = {"message": f"Update free key to {key}", "content": content, "branch": GITHUB_BRANCH}
            if sha:
                payload["sha"] = sha

            put_r = requests.put(url, headers=headers, json=payload, timeout=60)
            if put_r.status_code in (200, 201):
                pushed_to_github = True
            else:
                github_error = f"GitHub API {put_r.status_code}: {put_r.text[:150]}"
        except Exception as e:
            github_error = str(e)

    if pushed_to_github:
        embed = discord.Embed(
            title="✅ Key Updated & Published Live",
            description=f"New working key has been saved and pushed to GitHub:\n\n```\n{key}\n```\nAll players using `/key` and in-game authenticators will sync with this key immediately.",
            color=discord.Color.from_rgb(46, 204, 113),
        )
    else:
        desc = f"New key saved locally:\n```\n{key}\n```"
        if github_error:
            desc += f"\n\n⚠️ **GitHub sync note:** {github_error}"
        desc += "\nRun `python push_to_github.py` to push to GitHub manually."
        embed = discord.Embed(
            title="⚠️ Key Saved Locally",
            description=desc,
            color=discord.Color.from_rgb(243, 156, 18),
        )

    embed.set_footer(text="Frost Steel a Egg V4.6")
    await interaction.response.send_message(embed=embed)


@tree.command(name="script", description="Get the 1-line executor loadstring for Frost Steal an Egg")
async def script_command(interaction: discord.Interaction):
    script_url = github_raw_url("src/Loader.luau")
    loader = f'loadstring(game:HttpGet("{script_url}"))()'
    embed = discord.Embed(
        title="📜 Frost Steal an Egg — Script Loader",
        description=f"Paste this line into your Roblox executor:\n\n```lua\n{loader}\n```",
        color=discord.Color.from_rgb(235, 35, 45),
    )
    embed.set_footer(text="Frost Steel a Egg V4.6")
    await interaction.response.send_message(embed=embed)


@bot.event
async def on_ready():
    print(f"[Frost Bot] Logged in as {bot.user} (ID: {bot.user.id})")
    try:
        if GUILD_ID and GUILD_ID.isdigit():
            guild = discord.Object(id=int(GUILD_ID))
            synced = await tree.sync(guild=guild)
            print(f"[Frost Bot] Synced {len(synced)} command(s) to guild {GUILD_ID}")
        else:
            synced = await tree.sync()
            print(f"[Frost Bot] Synced {len(synced)} global command(s)")
    except Exception as e:
        print(f"[Frost Bot] Failed to sync commands: {e}")


if __name__ == "__main__":
    if not TOKEN:
        raise SystemExit("DISCORD_TOKEN is missing in .env")
    bot.run(TOKEN)