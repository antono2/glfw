#!/usr/bin/env python3
"""Generate the mechanical V surface from the pinned GLFW 3.5.1 header.

The handwritten glfw.v file owns compatibility names and semantic helpers.
Run `python3 tools/generate.py` after changing the pinned header, or use
`--check` to verify that the committed output is current.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HEADER = ROOT / "third_party" / "glfw3.h"
NATIVE_HEADER = ROOT / "third_party" / "glfw3native.h"
OUTPUT = ROOT / "glfw_generated.v"
EXPECTED_SHA256 = "95ecc16e4875bca18cff863232d5dbb623f3457b05f07efd26fe8bc8a06345b6"
EXPECTED_NATIVE_SHA256 = "d301085c2a998345c0f80127d8e67d4394f1c7b12ca9c2cf3b73b7fa15c804ae"


def v_type(c_type: str) -> str:
    c_type = re.sub(r"\bconst\b", "", c_type).strip()
    c_type = re.sub(r"\s+", " ", c_type)
    c_type = c_type.replace(" []", "*")
    depth = c_type.count("*")
    base = c_type.replace("*", "").strip()
    names = {
        "void": "voidptr" if depth else "",
        "char": "char",
        "unsigned char": "u8",
        "short": "i16",
        "unsigned short": "u16",
        "int": "i32",
        "unsigned int": "u32",
        "uint32_t": "u32",
        "uint64_t": "u64",
        "size_t": "usize",
        "float": "f32",
        "double": "f64",
        "GLFWwindow": "Window",
        "GLFWmonitor": "Monitor",
        "GLFWcursor": "Cursor",
        "GLFWvidmode": "VideoMode",
        "GLFWgammaramp": "GammaRamp",
        "GLFWimage": "Image",
        "GLFWgamepadstate": "GamepadState",
        "GLFWallocator": "Allocator",
        "GLFWkeyfun": "GLFWFnKey",
        "VkInstance": "vk.Instance",
        "VkPhysicalDevice": "vk.PhysicalDevice",
        "VkSurfaceKHR": "vk.SurfaceKHR",
        "VkAllocationCallbacks": "vk.AllocationCallbacks",
        "VkResult": "vk.Result",
        "PFN_vkGetInstanceProcAddr": "vk.PFN_vkGetInstanceProcAddr",
    }
    result = names.get(base, base)
    if base == "void":
        return "voidptr" if depth else ""
    if base in {"GLFWglproc", "GLFWvkproc"}:
        return "voidptr"
    if depth and result == "char":
        return "&" * depth + "char"
    if depth and result == "voidptr":
        return "voidptr" if depth == 1 else "&" * (depth - 1) + "voidptr"
    return "&" * depth + result


def parse_arg(part: str) -> str:
    part = part.strip()
    array = bool(re.search(r"\[[^]]*\]$", part))
    part = re.sub(r"\[[^]]*\]$", "", part)
    part = re.sub(r"\b[A-Za-z_]\w*$", "", part).strip()
    return v_type(part + ("*" if array else ""))


def parse_functions(header: str) -> list[tuple[str, str, list[str]]]:
    result = []
    for match in re.finditer(r"^GLFWAPI\s+(.+?)\s+(glfw\w+)\((.*?)\);", header, re.M):
        ret, name, args = match.groups()
        params = [] if args == "void" else [parse_arg(p) for p in args.split(",")]
        if any(not p for p in params):
            raise ValueError(f"unparsed parameters for {name}: {args}")
        result.append((name, v_type(ret), params))
    assert len(result) == 124, f"unexpected GLFW core function count: {len(result)}"
    return result


def parse_callbacks(header: str) -> list[tuple[str, str, list[str]]]:
    result = []
    for match in re.finditer(r"^typedef\s+(.+?)\s*\(\*\s*(GLFW\w+)\)\((.*?)\);", header, re.M):
        ret, name, args = match.groups()
        params = [] if args == "void" else [parse_arg(p) for p in args.split(",")]
        result.append((name, v_type(ret), params))
    assert len(result) == 25, f"unexpected GLFW callback count: {len(result)}"
    return result


def constants(header: str, existing: str) -> list[str]:
    values: dict[str, int] = {}
    result = []
    existing_values = {
        name: int(literal, 0)
        for name, literal in re.findall(r"pub const\s+(\w+)\s*=\s*(-?(?:0x[0-9a-fA-F]+|\d+))", existing)
    }
    for match in re.finditer(r"^#define\s+(GLFW_[A-Z0-9_]+)\s+([^\n]+)", header, re.M):
        macro, expr = match.groups()
        expr = re.sub(r"/\*.*?\*/", "", expr).strip()
        if not expr or "\\" in expr or '"' in expr:
            continue
        expanded = re.sub(r"\bGLFW_[A-Z0-9_]+\b", lambda m: str(values.get(m.group(), m.group())), expr)
        if not re.fullmatch(r"[0-9xa-fA-F()|&~+<> \-]+", expanded):
            continue
        try:
            value = eval(expanded, {"__builtins__": {}}, {})
        except (SyntaxError, ValueError):
            continue
        if not isinstance(value, int):
            continue
        values[macro] = value
        name = macro.removeprefix("GLFW_").lower()
        if name in {"true", "false"}:
            name = "_" + name
        if name in existing_values and existing_values[name] != value:
            raise ValueError(f"handwritten constant {name} differs from {macro}")
        if name not in existing_values:
            literal = f"u32({value})" if value > 0x7fffffff else str(value)
            result.append(f"pub const {name} = {literal}")
    assert len(values) == 333, f"unexpected GLFW constant count: {len(values)}"
    return result


def snake(name: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name.removeprefix("glfw")).lower()


def generate(header: str, handwritten: str) -> str:
    lines = [
        "// Generated by tools/generate.py from GLFW 3.5.1. Do not edit.",
        "module glfw",
        "",
        "import antono2.vulkan as vk",
        "",
        "// GLFW constants. Values come from the pinned upstream header.",
        *constants(header, handwritten),
        "",
        "pub type Cursor = C.GLFWcursor",
        "@[typedef]",
        "pub struct C.GLFWcursor {}",
        "",
    ]
    for c_name, v_name in [
        ("GLFWvidmode", "VideoMode"),
        ("GLFWgammaramp", "GammaRamp"),
        ("GLFWimage", "Image"),
        ("GLFWgamepadstate", "GamepadState"),
        ("GLFWallocator", "Allocator"),
    ]:
        match = re.search(r"typedef struct " + c_name + r"\s*\{(.*?)\}\s*" + c_name + r";", header, re.S)
        assert match, c_name
        body = re.sub(r"/\*.*?\*/", "", match.group(1), flags=re.S)
        lines += [f"pub type {v_name} = C.{c_name}", "@[typedef]", f"pub struct C.{c_name} {{", "pub:"]
        for field in body.split(";"):
            field = field.strip()
            if not field:
                continue
            member = re.fullmatch(r"(.+?)\s+(\w+)(?:\[(\d+)\])?", field)
            assert member, (c_name, field)
            typ, name, count = member.groups()
            mapped = v_type(typ)
            if count:
                mapped = f"[{count}]{mapped}"
            lines.append(f"\t{name} {mapped}")
        lines += ["}", ""]
    lines.append("// Raw callback signatures. Register named functions with C-compatible lifetimes.")
    for name, ret, params in parse_callbacks(header):
        if name == "GLFWerrorfun":
            continue
        args = ", ".join(f"arg{i} {typ}" for i, typ in enumerate(params))
        lines.append(f"pub type {name} = fn ({args})" + (f" {ret}" if ret else ""))
    lines += ["", "// Core GLFW functions not already present in the handwritten compatibility API."]
    existing_functions = set(re.findall(r"fn C\.(glfw\w+)\(", handwritten))
    for name, ret, params in parse_functions(header):
        if name in existing_functions:
            continue
        args = ", ".join(f"arg{i} {typ}" for i, typ in enumerate(params))
        c_params = ", ".join(params)
        suffix = f" {ret}" if ret else ""
        lines += ["", f"fn C.{name}({c_params}){suffix}", f"pub fn {snake(name)}({args}){suffix} {{"]
        call = f"C.{name}({', '.join(f'arg{i}' for i in range(len(params)))})"
        lines.append(f"\treturn {call}" if ret else f"\t{call}")
        lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = HEADER.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != EXPECTED_SHA256:
        raise SystemExit(f"pinned GLFW header hash mismatch: {digest}")
    native = NATIVE_HEADER.read_bytes()
    native_digest = hashlib.sha256(native).hexdigest()
    if native_digest != EXPECTED_NATIVE_SHA256:
        raise SystemExit(f"pinned GLFW native header hash mismatch: {native_digest}")
    native_functions = set(re.findall(r"^GLFWAPI\s+.+?\s+(glfw\w+)\(.*?\);", native.decode(), re.M))
    native_sources = "\n".join(path.read_text() for path in (ROOT / "native").glob("*/*.v"))
    missing_native = native_functions - set(re.findall(r"fn C\.(glfw\w+)\(", native_sources))
    if len(native_functions) != 27 or missing_native:
        raise SystemExit(f"native API coverage failure: {len(native_functions)} functions, missing {sorted(missing_native)}")
    result = generate(data.decode(), (ROOT / "glfw.v").read_text())
    result = subprocess.run(["v", "fmt"], input=result, text=True, capture_output=True, check=True).stdout
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != result:
            raise SystemExit("glfw_generated.v is stale; run python3 tools/generate.py")
        print("GLFW generated binding is current")
    else:
        OUTPUT.write_text(result)
        print(f"wrote {OUTPUT}")


if __name__ == "__main__":
    main()
