# Maintaining the GLFW binding

## Upstream updates

`third_party/glfw3.h` and `third_party/glfw3native.h` are pinned by
`third_party/upstream.json`, with the upstream license beside them. The weekly
`Update GLFW` workflow checks GitHub's latest stable release, updates the
headers and pin, regenerates the binding and opens a draft PR. The same update
can be run locally with:

```sh
v run tools/update_upstream.vsh
```

Existing V names are retained from the committed bindings; new GLFW structs
and declarations are discovered from the headers. The generator has no fixed
GLFW symbol inventory or counts. Generic C-to-V ABI conversion rules still
apply. If a new declaration cannot be represented, the update PR contains
`UPSTREAM_UPDATE.md` with the error. Resolve it and review ABI and ownership
changes before merging. Ownership-sensitive helpers belong in `convenience.v`.

## Source layout

- `glfw.v` preserves handwritten compatibility names and Vulkan wrappers.
- `glfw_generated.v` supplies the remaining core API. The generation
  code and its comments live in `tools/glfwgen/`. Use
  `v run tools/generate.vsh` to regenerate the file.
- `convenience.v` copies borrowed data and provides fallible window creation.
- `c/header.c.v` selects native headers and linker flags. `native/` contains
  optional backend-specific accessors; `examples/native_*_smoke.v` checks
  those platform imports without creating a graphical window.
- `glfw_test.v` tests the linked library and null-platform window behavior.
  `tools/build_native.vsh` builds the pinned native library in Linux and macOS CI.

The upstream headers in `third_party/` retain their original documentation and
license. Keep project-specific purpose comments in maintained source files and
generator templates rather than editing those vendored headers.

## Verification

Use V 0.5.2 or newer. The ABI probe and unit tests need the GLFW development
headers and library from the pinned release. The generator check only needs V
and the vendored headers.

| Command | Check |
| --- | --- |
| `v run tools/generate.vsh --check` | Reproduce the committed binding. |
| `v run tools/check_abi.vsh --cc gcc` | Compile and link each generated core wrapper. Use `msvc` or `clang` to check a different compiler. |
| `v test .` | Exercise the binding against the installed library. |

The CI workflow also checks Linux, Windows and macOS against the pinned GLFW
version.

## GitHub Actions configuration

The repository setting **Settings → Actions → General → Workflow permissions →
Allow GitHub Actions to create and approve pull requests** must be enabled for
the updater's `GITHUB_TOKEN` to open its draft PR. The workflow requests
`contents: write`, `pull-requests: write` and `actions: write`.

Scheduled workflows run from the default branch. GitHub may disable them after
60 days without activity in a public repository; if that happens, re-enable
`Update GLFW` in the Actions tab. `workflow_dispatch` allows a manual check.
