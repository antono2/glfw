#!/usr/bin/env bash
# Builds the pinned shared GLFW release with Wayland support for Linux CI.
# Exports matching header, library and runtime paths to later GitHub Actions steps.
set -euo pipefail

version=$(python3 -c "import json; print(json.load(open('modules/antono2/glfw/third_party/upstream.json'))['version'])")
prefix="$RUNNER_TEMP/glfw-$version"
source="$RUNNER_TEMP/glfw-$version-source"
git clone --depth 1 --branch "$version" https://github.com/glfw/glfw.git "$source"
cmake -S "$source" -B "$source/build" \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DBUILD_SHARED_LIBS=ON \
  -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF \
  -DGLFW_BUILD_WAYLAND=ON
cmake --build "$source/build" --parallel
cmake --install "$source/build"
{
  echo "GLFW_INCLUDE=$prefix/include"
  echo "GLFW_LIB=$prefix/lib"
  echo "LD_LIBRARY_PATH=$prefix/lib"
} >> "$GITHUB_ENV"
