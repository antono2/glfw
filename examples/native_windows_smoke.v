module main

import antono2.glfw.native.win32

fn main() {
	assert isnil(win32.window(unsafe { nil }))
}
