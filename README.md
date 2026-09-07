# Focused [GLFW](https://www.glfw.org/) bindings for [V](https://vlang.io/)

## Dependencies

This module links to the system GLFW library and uses the Vulkan types from
`antono2/vulkan`.

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y build-essential libglfw3-dev libvulkan-dev libvulkan-volk-dev
export VULKAN_SDK=/usr
v install antono2.vulkan
```

On Windows, install GLFW and the Vulkan SDK, then set `GLFW_INCLUDE`,
`GLFW_LIB`, and `VULKAN_SDK` to their corresponding directories. The Windows
library directory must contain `glfw3.lib` for MSVC builds.

## Install

```bash
v install antono2.glfw
```

For a standard 64-bit Ubuntu/Debian installation, set `GLFW_INCLUDE` to
`/usr/include`, `GLFW_LIB` to `/usr/lib/x86_64-linux-gnu`, and `VULKAN_SDK` to
`/usr`. Use the actual paths when libraries are installed elsewhere.

## Supported scope

The binding provides the subset used by the ImGui and Vulkan Video examples:

- GLFW initialization and termination;
- Vulkan-compatible window creation and destruction;
- event polling, key state/callbacks, framebuffer size, and close state;
- required Vulkan instance extensions, presentation support, and surface
  creation.

It is not a complete GLFW binding. OpenGL context management, monitors, input
devices, clipboard access, cursors, and most window-management functions are
not currently wrapped.

## Example

See the tested GLFW/Vulkan example in
[`antono2/v_imgui_examples`](https://github.com/antono2/v_imgui_examples).

## Tests

```bash
v test .
```

The module smoke test compiles and links the native GLFW dependency without
opening a window, so it is suitable for headless CI. Window creation and resize
behavior are exercised by the ImGui demo and Vulkan Video player.

## Status

This focused API is sufficient for the related Vulkan projects. Applications
needing broad GLFW coverage may prefer
[`duarteroso/glfw`](https://github.com/duarteroso/glfw).
