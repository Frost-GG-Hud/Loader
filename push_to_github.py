import base64
import json
import os
import sys

import requests
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

TOKEN = os.getenv("GITHUB_TOKEN", "")
REPO = os.getenv("GITHUB_REPO", "Frost-GG-Hud/Loader")
BRANCH = os.getenv("GITHUB_BRANCH", "main")

FILES = [
    "bot.py",
    "server.py",
    "push_to_github.py",
    "render.yaml",
    "Procfile",
    "requirements.txt",
    "keys.json",
    "src/main.luau",
    "src/Loader.luau",
    "README.md",
    ".env.example",
    ".gitignore",
]

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
}


def main():
    if not TOKEN:
        sys.exit("GITHUB_TOKEN is empty. Put it in .env and re-run.")

    r = requests.get(f"https://api.github.com/repos/{REPO}", headers=HEADERS, timeout=30)
    if r.status_code == 404:
        sys.exit(f"Repo {REPO} not found or token has no access to it.")
    if r.status_code == 401:
        sys.exit("Token is invalid or expired.")
    r.raise_for_status()

    for path in FILES:
        local = os.path.join(BASE_DIR, path)
        if not os.path.exists(local):
            print(f"SKIP {path} (not present locally)")
            continue
        with open(local, "rb") as f:
            content = base64.b64encode(f.read()).decode("utf-8")

        url = f"https://api.github.com/repos/{REPO}/contents/{path}"
        existing = requests.get(url, headers=HEADERS, timeout=30).json()
        sha = existing.get("sha")
        payload = {
            "message": f"Update {path}",
            "content": content,
            "branch": BRANCH,
        }
        if sha:
            payload["sha"] = sha
        put = requests.put(url, headers=HEADERS, json=payload, timeout=60)
        if put.status_code in (200, 201):
            print(f"OK   {path}")
        else:
            print(f"FAIL {path}: {put.status_code} {put.text[:200]}")


if __name__ == "__main__":
    main()