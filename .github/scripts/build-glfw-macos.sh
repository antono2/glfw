#!/usr/bin/env bash
set -euo pipefail

version=$(python3 -c "import json; print(json.load(open('modules/antono2/glfw/third_party/upstream.json'))['version'])")
prefix="$RUNNER_TEMP/glfw-$version"
source="$RUNNER_TEMP/glfw-$version-source"
git clone --depth 1 --branch "$version" https://github.com/glfw/glfw.git "$source"
cmake -S "$source" -B "$source/build" \
  -DCMAKE_INSTALL_PREFIX="$prefix" -DBUILD_SHARED_LIBS=ON \
  -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF
cmake --build "$source/build" --parallel
cmake --install "$source/build"
{
  echo "GLFW_INCLUDE=$prefix/include"
  echo "GLFW_LIB=$prefix/lib"
  echo "DYLD_LIBRARY_PATH=$prefix/lib"
  echo "VULKAN_SDK=$(brew --prefix vulkan-loader)"
} >> "$GITHUB_ENV"
