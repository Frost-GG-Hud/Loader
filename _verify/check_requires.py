"""Verify the module graph: every ctx.require("x") must map to a real file.

The hub is loaded over HTTP one module at a time, so a require path that does not
exist is a runtime failure with no compiler warning. This checks the graph
statically.
"""

import re
import sys
from pathlib import Path

SRC = Path("src")
REQUIRE_PATTERN = re.compile(r'ctx\.require\(\s*"([^"]+)"\s*\)')


def main() -> int:
    problems = []
    required: set[str] = set()
    declared = {p.relative_to(SRC).with_suffix("").as_posix() for p in SRC.rglob("*.luau")}

    for path in sorted(SRC.rglob("*.luau")):
        text = path.read_text(encoding="utf-8")
        for target in REQUIRE_PATTERN.findall(text):
            required.add(target)
            if target not in declared:
                problems.append(f"{path}: requires '{target}' which does not exist (expected src/{target}.luau)")

    # Modules that nothing requires are dead weight.
    entrypoints = {"main", "Loader"}
    orphans = sorted(declared - required - entrypoints)
    unreachable = [name for name in orphans if name not in {"core/Config"}]

    if problems:
        print("\n".join(problems))
        return 1

    print(f"OK: {len(required)} requires across {len(declared)} files, all resolve")
    if unreachable:
        print("Note: modules nobody requires (excluding entrypoints): " + ", ".join(unreachable))
    return 0


if __name__ == "__main__":
    sys.exit(main())
