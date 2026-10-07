// Compile/link smoke check for Cocoa native window access on macOS.
// Checks the uninitialized getter without creating an application window.
module main

import antono2.glfw.native.cocoa

fn main() {
	assert isnil(cocoa.window(unsafe { nil }))
}
