#!/usr/bin/env python3
"""Compile and link calls to every generated core function without executing them."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

import generate


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cc", default="gcc")
    args = parser.parse_args()
    existing = set(re.findall(r"fn C\.(glfw\w+)\(", (generate.ROOT / "glfw.v").read_text()))
    lines = [
        "module main",
        "import os",
        "import antono2.glfw",
        "fn main() {",
        "    if os.args.len > 100000 {",
    ]
    count = 0
    for name, ret, params in generate.parse_functions(generate.HEADER.read_text()):
        if name in existing:
            continue
        values = [
            "unsafe { nil }" if typ.startswith("&") or typ == "voidptr" or typ.startswith("GLFW") or typ.startswith("vk.") else "0"
            for typ in params
        ]
        call = f"glfw.{generate.snake(name)}({', '.join(values)})"
        lines.append("        " + ("_ = " if ret else "") + call)
        count += 1
    lines += ["    }", "}"]
    with tempfile.TemporaryDirectory() as directory:
        module_root = Path(directory) / "antono2" / "glfw"
        shutil.copytree(generate.ROOT, module_root, ignore=shutil.ignore_patterns(".git", "__pycache__"))
        path = Path(directory) / "abi_probe.v"
        path.write_text("\n".join(lines) + "\n")
        subprocess.run(["v", "-path", f"{directory}|@vlib|@vmodules", "-cc", args.cc, "run", str(path)], check=True)
    print(f"Compiled and linked {count} generated GLFW calls")


if __name__ == "__main__":
    main()
