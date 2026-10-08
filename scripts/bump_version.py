#!/usr/bin/env python3
"""Set the plugin version, which shares one version line with the actions.

The repo publishes two things from one tag: the composite actions that consumers
reference as `uses: RijksICTGilde/zad-actions/deploy@v4`, and the Claude Code /
Cursor plugin that the developer.overheid.nl marketplace installs. They share a
single version so there is only ever one number to reason about, and the release
workflow refuses a tag whose version does not match `.plugin/plugin.json`.

Usage:
    python scripts/bump_version.py 4.3.1   # set the version
    python scripts/bump_version.py --check 4.3.1
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
SOURCE_PATH = ROOT_DIR / ".plugin" / "plugin.json"
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


def read_version() -> str:
    with open(SOURCE_PATH) as f:
        return json.load(f)["version"]


def write_version(version: str) -> None:
    with open(SOURCE_PATH) as f:
        data = json.load(f)
    data["version"] = version
    with open(SOURCE_PATH, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def regenerate() -> None:
    """Regenerate the platform files so all three manifests agree."""
    subprocess.run(
        [sys.executable, str(ROOT_DIR / "scripts" / "generate_plugin.py")],
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="the version to set, without a leading v")
    parser.add_argument(
        "--check",
        action="store_true",
        help="only verify that the version matches, change nothing",
    )
    args = parser.parse_args()

    version = args.version.lstrip("v")
    if not SEMVER_RE.match(version):
        print(f"FOUT: '{version}' is geen x.y.z versie", file=sys.stderr)
        return 1

    current = read_version()

    if args.check:
        if current != version:
            print(
                f"FOUT: .plugin/plugin.json staat op {current}, verwacht {version}",
                file=sys.stderr,
            )
            return 1
        print(f"OK: plugin-versie is {current}")
        return 0

    if current == version:
        print(f"Plugin-versie staat al op {version}")
    else:
        write_version(version)
        print(f"Plugin-versie: {current} -> {version}")

    regenerate()
    print(f"\nKlaar. Commit de drie manifests, dan taggen met v{version}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
