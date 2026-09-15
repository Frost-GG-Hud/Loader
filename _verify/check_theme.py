"""Cross-check every Theme.<field> / M.<field> reference against core/Theme.luau.

A typo such as Theme.WHITE instead of Theme.White evaluates to nil at runtime and
only surfaces as a crash on the line that consumes it, so it is worth catching
statically.
"""

import re
import sys
from pathlib import Path

SRC = Path("src")
THEME_FILE = SRC / "core" / "Theme.luau"


def defined_fields() -> tuple[set[str], set[str]]:
    text = THEME_FILE.read_text(encoding="utf-8")

    metrics_block = re.search(r"Theme\.Metrics\s*=\s*\{(.*?)\n\}", text, re.S)
    metrics = set()
    if metrics_block:
        metrics = set(re.findall(r"^\t(\w+)\s*=", metrics_block.group(1), re.M))

    top_block = re.search(r"^local Theme = \{(.*?)\n\}", text, re.S | re.M)
    fields = set()
    if top_block:
        fields |= set(re.findall(r"^\t(\w+)\s*=", top_block.group(1), re.M))

    # Theme.FontRegular = ..., Theme.Metrics = ..., function Theme.x() ...
    fields |= set(re.findall(r"^Theme\.(\w+)\s*=", text, re.M))
    fields |= set(re.findall(r"^function Theme\.(\w+)\(", text, re.M))

    return fields, metrics


def main() -> int:
    fields, metrics = defined_fields()
    problems = []

    for path in sorted(SRC.rglob("*.luau")):
        if path == THEME_FILE:
            continue
        text = path.read_text(encoding="utf-8")
        for line_no, line in enumerate(text.splitlines(), start=1):
            for name in re.findall(r"\bTheme\.(\w+)", line):
                if name == "Metrics":
                    continue
                if name not in fields:
                    problems.append(f"{path}:{line_no}: Theme.{name} is not defined")
            for name in re.findall(r"\bTheme\.Metrics\.(\w+)", line):
                if name not in metrics:
                    problems.append(f"{path}:{line_no}: Theme.Metrics.{name} is not defined")
            # `local M = Theme.Metrics` is the conventional alias in this project.
            if re.search(r"local M = Theme\.Metrics", text):
                for name in re.findall(r"(?<![\w.])M\.(\w+)", line):
                    if name not in metrics:
                        problems.append(f"{path}:{line_no}: M.{name} is not defined in Theme.Metrics")

    if problems:
        print("\n".join(problems))
        return 1

    print(f"OK: {len(fields)} Theme fields, {len(metrics)} metric fields, no bad references")
    return 0


if __name__ == "__main__":
    sys.exit(main())
