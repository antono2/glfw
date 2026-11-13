// Native startup probe: no GPU, renderer or input injection is required.
module main

import antono2.glfw

fn main() {
	if !glfw.initialize() { panic('GLFW initialization failed') }
	defer { glfw.terminate() }
	glfw.window_hint(glfw.client_api, glfw.no_api)
	glfw.window_hint(glfw.visible, 0)
	window := glfw.create_windowed(640, 480, 'GLFW startup probe') or { panic(err) }
	defer { glfw.destroy_window(window) }
	glfw.show_window_and_wait(window) or { panic(err) }
}
