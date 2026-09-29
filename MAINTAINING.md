# Maintaining the GLFW binding

## Upstream updates

`third_party/glfw3.h` and `third_party/glfw3native.h` are pinned by
`third_party/upstream.json`, with the upstream license beside them. The weekly
`Update GLFW` workflow checks GitHub's latest stable release, updates the
headers and pin, regenerates the binding, and opens a draft PR. The same update
can be run locally with:

```sh
python3 tools/update_upstream.py
```

Existing V names are retained from the committed bindings; new GLFW structs
and declarations are discovered from the headers. The generator has no fixed
GLFW symbol inventory or counts. Generic C-to-V ABI conversion rules still
apply. If a new declaration cannot be represented, the update PR contains
`UPSTREAM_UPDATE.md` with the error. Resolve it and review ABI and ownership
changes before merging. Ownership-sensitive helpers belong in `convenience.v`.

## Verification

With the matching GLFW development headers and library installed:

```sh
python3 tools/generate.py --check
python3 tools/check_abi.py --cc gcc
v test .
```

The CI workflow also checks Linux, Windows, and macOS against the pinned GLFW
version.

## GitHub Actions configuration

The repository setting **Settings → Actions → General → Workflow permissions →
Allow GitHub Actions to create and approve pull requests** must be enabled for
the updater's `GITHUB_TOKEN` to open its draft PR. The workflow requests
`contents: write`, `pull-requests: write`, and `actions: write`.

Scheduled workflows run from the default branch. GitHub may disable them after
60 days without activity in a public repository; if that happens, re-enable
`Update GLFW` in the Actions tab. `workflow_dispatch` allows a manual check.
