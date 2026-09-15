import json
import mimetypes
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(BASE_DIR, "src")
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
ADMIN_TOKEN = os.getenv("SITE_ADMIN_TOKEN", "")
KEY_FILE = os.getenv("KEY_FILE", os.path.join(BASE_DIR, "keys.json"))

MAX_BODY = 64 * 1024


def read_key() -> str:
    try:
        with open(KEY_FILE, "r", encoding="utf-8") as f:
            return json.load(f).get("current", "")
    except (OSError, json.JSONDecodeError):
        return ""


def write_key(key: str):
    with open(KEY_FILE, "w", encoding="utf-8") as f:
        json.dump({"current": key}, f, indent=2)
        f.write("\n")


def load_script() -> str:
    with open(os.path.join(SRC_DIR, "main.luau"), "r", encoding="utf-8") as f:
        return f.read()


def load_loader() -> str:
    with open(os.path.join(SRC_DIR, "Loader.luau"), "r", encoding="utf-8") as f:
        return f.read()


def mime_for(path: str) -> str:
    ctype, _ = mimetypes.guess_type(path)
    if ctype and ctype.startswith("text/"):
        return ctype + "; charset=utf-8"
    if path.endswith(".luau") or path.endswith(".lua"):
        return "text/plain; charset=utf-8"
    return ctype or "application/octet-stream"


class Handler(BaseHTTPRequestHandler):
    server_version = "FrostHost/1.0"

    def _headers(self, ctype: str):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _send(self, body: bytes, ctype: str):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj: dict, code: int = 200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _not_found(self):
        self._json({"error": "Not found"}, 404)

    def _index(self):
        proto = "https" if self.headers.get("X-Forwarded-Proto") == "https" else "http"
        host = self.headers.get("Host") or f"localhost:{PORT}"
        base = f"{proto}://{host}"
        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Frost script host</title>
</head>
<body style="font-family: system-ui, sans-serif; max-width: 640px; margin: 40px auto;">
<h1>Frost script host</h1>
<p>Paste this into your executor:</p>
<pre><code>loadstring(game:HttpGet("{base}/api/script"))()</code></pre>
<p>Endpoints:</p>
<ul>
<li><a href="{base}/api/script">/api/script</a> - main hub script</li>
<li><a href="{base}/Loader.luau">/Loader.luau</a> - loader script</li>
<li><a href="{base}/keys.json">/keys.json</a> - current key</li>
</ul>
</body>
</html>"""
        self._send(html.encode("utf-8"), "text/html; charset=utf-8")

    def _static(self, raw_path: str):
        clean = os.path.normpath(raw_path.strip("/"))
        candidates = [
            os.path.join(BASE_DIR, clean),
            os.path.join(SRC_DIR, clean),
        ]
        for cand in candidates:
            cand = os.path.abspath(cand)
            if not cand.startswith(BASE_DIR):
                continue
            if not os.path.isfile(cand):
                continue
            with open(cand, "rb") as f:
                self._send(f.read(), mime_for(cand))
            return
        self._not_found()

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            self._index()
        elif path in ("/api/script", "/main.luau", "/src/main.luau"):
            self._send(load_script().encode("utf-8"), "text/plain; charset=utf-8")
        elif path in ("/Loader.luau", "/src/Loader.luau"):
            self._send(load_loader().encode("utf-8"), "text/plain; charset=utf-8")
        elif path in ("/keys.json", "/api/key"):
            self._json({"current": read_key()})
        elif path == "/health":
            self._json({"ok": True})
        else:
            self._static(path)

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path not in ("/api/setkey", "/api/key"):
            self._not_found()
            return
        if not ADMIN_TOKEN:
            self._json({"error": "SITE_ADMIN_TOKEN is not configured"}, 503)
            return
        if self.headers.get("X-Admin-Token") != ADMIN_TOKEN:
            self._json({"error": "Invalid admin token"}, 401)
            return
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > MAX_BODY:
            self._json({"error": "Bad body size"}, 400)
            return
        body = self.rfile.read(length).decode("utf-8", "replace")
        key = ""
        try:
            parsed = json.loads(body)
            if isinstance(parsed, dict):
                key = str(parsed.get("key", ""))
            elif isinstance(parsed, str):
                key = parsed
        except (json.JSONDecodeError, TypeError):
            key = body.strip()
        key = key.strip()
        if not key:
            self._json({"error": "No key given"}, 400)
            return
        write_key(key)
        self._json({"current": key})

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-Admin-Token")
        self.end_headers()

    def log_message(self, fmt, *args):
        print("[server] %s - %s" % (self.address_string(), fmt % args))


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    print(f"[server] Frozen host on http://{HOST}:{PORT}")
    print(f"[server] /api/script serves src/main.luau, /keys.json serves the live key")
    Server((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()