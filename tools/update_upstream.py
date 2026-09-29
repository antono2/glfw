#!/usr/bin/env python3
"""Update the pinned headers from the latest stable GLFW release.

The updater changes data and generated code only. A reviewable PR is opened by
the scheduled workflow; unsupported new ABI shapes remain visible as CI errors.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PIN = ROOT / "third_party" / "upstream.json"
NOTES = ROOT / "UPSTREAM_UPDATE.md"
HEADERS = ("glfw3.h", "glfw3native.h")


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "antono2-glfw-updater", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def version_tuple(value: str) -> tuple[int, int, int]:
    if not re.fullmatch(r"\d+\.\d+\.\d+", value):
        raise ValueError(f"unsupported GLFW release tag: {value}")
    return tuple(map(int, value.split(".")))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", help="test a specific stable release tag")
    args = parser.parse_args()
    current = json.loads(PIN.read_text())
    if args.tag:
        tag = args.tag
    else:
        release = json.loads(fetch("https://api.github.com/repos/glfw/glfw/releases/latest"))
        if release.get("draft") or release.get("prerelease"):
            raise RuntimeError("GitHub's latest release is not stable")
        tag = release["tag_name"]
    if version_tuple(tag) <= version_tuple(current["version"]):
        print(f"GLFW {current['version']} is current")
        return
    if version_tuple(tag)[0] != version_tuple(current["version"])[0]:
        raise RuntimeError(f"GLFW {tag} changes the major version; review the upgrade manually")

    downloaded = {name: fetch(f"https://raw.githubusercontent.com/glfw/glfw/{tag}/include/GLFW/{name}") for name in HEADERS}
    header = downloaded["glfw3.h"].decode()
    actual = tuple(int(re.search(r"^#define GLFW_VERSION_" + part + r"\s+(\d+)", header, re.M).group(1)) for part in ("MAJOR", "MINOR", "REVISION"))
    if actual != version_tuple(tag):
        raise RuntimeError(f"release tag {tag} does not match header version {actual}")
    for name, data in downloaded.items():
        (ROOT / "third_party" / name).write_bytes(data)
    PIN.write_text(json.dumps({"version": tag, "tag": tag, "headers": {name: hashlib.sha256(data).hexdigest() for name, data in downloaded.items()}}, indent=2) + "\n")

    result = subprocess.run([sys.executable, str(ROOT / "tools" / "generate.py")], cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        NOTES.write_text(f"# GLFW {tag} update needs binding work\n\nThe header and pin were updated, but generation failed:\n\n```text\n{result.stdout}{result.stderr}```\n\nResolve the unsupported declarations, regenerate, and remove this file.\n")
        print(NOTES.read_text())
    else:
        NOTES.unlink(missing_ok=True)
        print(result.stdout, end="")


if __name__ == "__main__":
    main()
