module main

import antono2.glfw.native.cocoa

fn main() {
	assert isnil(cocoa.window(unsafe { nil }))
}
