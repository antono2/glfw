// Optional X11 and GLX access for GLFW windows, monitors and selection text.
// Native handles remain borrowed; use with an X11-enabled GLFW build.
module x11

import antono2.glfw

#flag linux -DGLFW_EXPOSE_NATIVE_X11
#flag linux -DGLFW_EXPOSE_NATIVE_GLX
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

fn C.glfwGetX11Display() voidptr
fn C.glfwGetX11Adapter(&glfw.Monitor) usize
fn C.glfwGetX11Monitor(&glfw.Monitor) usize
fn C.glfwGetX11Window(&glfw.Window) usize
fn C.glfwSetX11SelectionString(&char)
fn C.glfwGetX11SelectionString() &char
fn C.glfwGetGLXContext(&glfw.Window) voidptr
fn C.glfwGetGLXWindow(&glfw.Window) usize
fn C.glfwGetGLXFBConfig(&glfw.Window, &voidptr) i32

pub fn display() voidptr {
	return C.glfwGetX11Display()
}

pub fn adapter(monitor &glfw.Monitor) usize {
	return C.glfwGetX11Adapter(monitor)
}

pub fn monitor(monitor &glfw.Monitor) usize {
	return C.glfwGetX11Monitor(monitor)
}

pub fn window(window &glfw.Window) usize {
	return C.glfwGetX11Window(window)
}

pub fn set_selection_string(value string) {
	C.glfwSetX11SelectionString(value.str)
}

pub fn selection_string() ?string {
	pointer := C.glfwGetX11SelectionString()
	if isnil(pointer) { return none }
	return unsafe { pointer.vstring() }.clone()
}

pub fn glx_context(window &glfw.Window) voidptr {
	return C.glfwGetGLXContext(window)
}

pub fn glx_window(window &glfw.Window) usize {
	return C.glfwGetGLXWindow(window)
}

pub fn glx_fb_config(window &glfw.Window, config &voidptr) bool {
	return C.glfwGetGLXFBConfig(window, config) == glfw._true
}
