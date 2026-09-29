# [GLFW](https://www.glfw.org/) bindings for [V](https://vlang.io/)

[Project portfolio](https://oreskin.de/projects_en.php)

The main `antono2.glfw` module covers the 124 public functions, constants,
callback signatures, and data structures in GLFW 3.5.1's `glfw3.h`. The
platform-specific native functions in `glfw3native.h` are provided as optional
submodules under `native/`. The existing Vulkan-oriented API names remain
available.

## Requirements and setup

The binding links to a GLFW **3.5.1 or later 3.x** library and headers. The
installed library must match the selected headers. It also currently requires
`antono2.vulkan@v3.2.0` for GLFW's Vulkan functions.

Install Vulkan, build or install GLFW 3.5.1, install this V module, and run
setup checks. Linux and macOS run headless tests; Windows checks syntax here
and runs linked MSVC tests in CI:

```sh
v run setup.vsh
```

For a read-only diagnostic pass:

```sh
v run setup.vsh --check
```

The installer builds GLFW 3.5.1 from its release tag on Linux and Windows;
macOS uses Homebrew. When setting up manually, point `GLFW_INCLUDE` to the
directory containing `GLFW/glfw3.h` and `GLFW_LIB` to the matching library
directory. On Linux, add that library directory to `LD_LIBRARY_PATH` at run
time. Windows MSVC builds require `glfw3.lib` in `GLFW_LIB`. `VULKAN_SDK`
must point to a compatible Vulkan SDK.

The checked-in headers in `third_party/` are pinned inputs to the generator;
they do not replace the installed GLFW development package at compile time.

## Raw and convenience APIs

The generated API follows GLFW's C signatures and snake-case names. It leaves
GLFW-owned pointers borrowed. The handwritten convenience functions copy
strings, monitor/video-mode data, joystick data, and Vulkan extensions into
V-owned values, expose sizes as `Size`, and offer `create_windowed` and
`create_window_checked` for fallible creation.

```v
import antono2.glfw

glfw.init_hint(glfw.platform, glfw.platform_null) // headless example
if !glfw.initialize() {
    panic('GLFW initialization failed')
}
defer { glfw.terminate() }

glfw.window_hint(glfw.client_api, glfw.no_api)
window := glfw.create_windowed(640, 480, 'Example')!
defer { glfw.destroy_window(window) }

size := glfw.framebuffer_size(window)
println('${size.width} × ${size.height}')
```

The raw callback setters accept named V functions with the generated callback
signature. Keep callback-owned data for only as long as GLFW documents; for
example, copy dropped paths inside the drop callback if they must survive it.
GLFW requires most window and event operations on the main thread.

## Native access

Import the relevant optional submodule: `antono2.glfw.native.x11`,
`antono2.glfw.native.wayland`, `antono2.glfw.native.win32`,
`antono2.glfw.native.cocoa`, `antono2.glfw.native.egl`, or
`antono2.glfw.native.osmesa`. These expose
all 27 `glfw3native.h` functions. Use only modules whose backends were enabled
when the linked GLFW library was built. The EGL and OSMesa modules additionally
need their development headers; Wayland needs Wayland headers. Native handles
are borrowed and use `voidptr` or `usize` where V has no platform type.

## Binding updates

`third_party/glfw3.h` and `third_party/glfw3native.h` are pinned to GLFW
3.5.1, with the upstream license beside them. The generator verifies their
hashes and checks coverage of the core and native functions:

```sh
python3 tools/generate.py --check
python3 tools/check_abi.py --cc gcc
```

When updating GLFW, replace the pinned headers, update the expected hashes and
API counts in `tools/generate.py`, regenerate `glfw_generated.v`, and review the
diff. Keep ownership-sensitive helpers in `convenience.v` rather than adding
them to generated output.

Run the headless tests with the matching installed GLFW:

```sh
v test .
```

The GLFW/Vulkan example in
[`antono2/v_imgui_examples`](https://github.com/antono2/v_imgui_examples)
shows the binding in a graphical application.
