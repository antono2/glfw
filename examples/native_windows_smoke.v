// Compile/link smoke check for Win32 native window access on Windows.
// Checks the uninitialized getter without creating an application window.
module main

import antono2.glfw.native.win32

fn main() {
	assert isnil(win32.window(unsafe { nil }))
}
