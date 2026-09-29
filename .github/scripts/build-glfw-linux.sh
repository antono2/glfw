#!/usr/bin/env bash
set -euo pipefail

prefix="$RUNNER_TEMP/glfw-3.5.1"
source="$RUNNER_TEMP/glfw-3.5.1-source"
git clone --depth 1 --branch 3.5.1 https://github.com/glfw/glfw.git "$source"
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
