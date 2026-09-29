module main

import antono2.glfw.native.egl
import antono2.glfw.native.osmesa
import antono2.glfw.native.wayland
import antono2.glfw.native.x11

fn main() {
	// Native getters report no handle before GLFW is initialized. This also
	// verifies the optional modules compile and link against the selected GLFW.
	assert isnil(x11.display())
	assert isnil(wayland.display())
	assert isnil(egl.display())
	assert isnil(osmesa.context(unsafe { nil }))
}
