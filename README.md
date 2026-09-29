# [GLFW](https://www.glfw.org/) bindings for [V](https://vlang.io/)

[Project portfolio](https://oreskin.de/projects_en.php)

The main `antono2.glfw` module covers the public functions, constants,
callback signatures, and data structures in the pinned GLFW `glfw3.h`. The
platform-specific native functions in `glfw3native.h` are provided as optional
submodules under `native/`. The existing Vulkan-oriented API names remain
available.

## Requirements and setup

The binding links to a GLFW library and headers at least as new as the version
in `third_party/upstream.json`, within the same major release. The
installed library must match the selected headers. It also currently requires
`antono2.vulkan@v3.2.0` for GLFW's Vulkan functions.

Install Vulkan, build or install the pinned GLFW release, install this V module, and run
setup checks. Linux and macOS run headless tests; Windows checks syntax here
and runs linked MSVC tests in CI:

```sh
v run setup.vsh
```

For a read-only diagnostic pass:

```sh
v run setup.vsh --check
```

The installer builds the pinned GLFW release from its tag on Linux, macOS,
and Windows. When setting up manually, point `GLFW_INCLUDE` to the
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
the native functions in the pinned `glfw3native.h`. Use only modules whose backends were enabled
when the linked GLFW library was built. The EGL and OSMesa modules additionally
need their development headers; Wayland needs Wayland headers. Native handles
are borrowed and use `voidptr` or `usize` where V has no platform type.

## Binding updates

`third_party/glfw3.h` and `third_party/glfw3native.h` are pinned by
`third_party/upstream.json`, with the upstream license beside them. The generator
verifies their hashes and checks coverage of the core and native functions:

```sh
python3 tools/generate.py --check
python3 tools/check_abi.py --cc gcc
```

The weekly `Update GLFW` workflow checks GitHub's latest stable GLFW release,
updates the headers and pin, regenerates the bindings, and opens a draft PR.
Run `python3 tools/update_upstream.py` to do the same locally. Existing V names
are retained from the committed bindings; new GLFW structs and declarations
are discovered from the headers. There are no pinned symbol counts or type-name
lists in the generator. Generic C-to-V ABI conversion rules still apply; if a
new declaration cannot be represented, `UPSTREAM_UPDATE.md` records the failure
in the draft PR for manual repair. Review ABI and ownership changes before
merging. Keep ownership-sensitive helpers in `convenience.v`.

The workflow needs the repository Actions setting **Allow GitHub Actions to
create and approve pull requests** enabled. It requests `contents: write`,
`pull-requests: write`, and `actions: write` for its own token. Scheduled
workflows run from the default branch, so this workflow starts after its PR is
merged. GitHub may disable schedules after 60 days without repository activity.

Run the headless tests with the matching installed GLFW:

```sh
v test .
```

The GLFW/Vulkan example in
[`antono2/v_imgui_examples`](https://github.com/antono2/v_imgui_examples)
shows the binding in a graphical application.
