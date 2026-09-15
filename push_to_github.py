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
    "push_to_github.py",
    "requirements.txt",
    "keys.json",
    "src/Loader.luau",
    "src/main.luau",
    "src/core/Config.luau",
    "src/core/Http.luau",
    "src/core/Theme.luau",
    "src/core/Util.luau",
    "src/features/Universal.luau",
    "src/features/StealAnEgg/EggData.luau",
    "src/features/StealAnEgg/Esp.luau",
    "src/features/StealAnEgg/Init.luau",
    "src/features/StealAnEgg/Movement.luau",
    "src/ui/Builder.luau",
    "src/ui/DragController.luau",
    "src/ui/Header.luau",
    "src/ui/KeyPrompt.luau",
    "src/ui/Notify.luau",
    "src/ui/Tab.luau",
    "src/ui/Window.luau",
    "src/ui/widgets/Button.luau",
    "src/ui/widgets/GridRow.luau",
    "src/ui/widgets/Init.luau",
    "src/ui/widgets/Label.luau",
    "src/ui/widgets/Section.luau",
    "src/ui/widgets/Slider.luau",
    "src/ui/widgets/TextInput.luau",
    "src/ui/widgets/Toggle.luau",
    "README.md",
    ".env.example",
    ".gitignore",
]

# Files that used to exist but are no longer part of the project (website hosting removed).
DELETE_FILES = [
    "server.py",
    "render.yaml",
    "Procfile",
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

    for path in DELETE_FILES:
        url = f"https://api.github.com/repos/{REPO}/contents/{path}"
        existing = requests.get(url, headers=HEADERS, timeout=30)
        if existing.status_code == 404:
            print(f"SKIP delete {path} (not on GitHub)")
            continue
        sha = existing.json().get("sha")
        if not sha:
            print(f"SKIP delete {path} (no sha)")
            continue
        payload = {"message": f"Remove {path} (website hosting removed)", "sha": sha, "branch": BRANCH}
        del_resp = requests.delete(url, headers=HEADERS, json=payload, timeout=30)
        if del_resp.status_code in (200, 204):
            print(f"DELETED {path}")
        else:
            print(f"FAIL delete {path}: {del_resp.status_code} {del_resp.text[:200]}")


if __name__ == "__main__":
    main()