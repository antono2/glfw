// Optional Win32 and WGL access for GLFW windows and monitors.
// Adapter and monitor names are copied into V strings; window/context handles remain borrowed.
module win32

import antono2.glfw

#flag windows -DGLFW_EXPOSE_NATIVE_WIN32
#flag windows -DGLFW_EXPOSE_NATIVE_WGL
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

fn C.glfwGetWin32Adapter(&glfw.Monitor) &char
fn C.glfwGetWin32Monitor(&glfw.Monitor) &char
fn C.glfwGetWin32Window(&glfw.Window) voidptr
fn C.glfwGetWGLContext(&glfw.Window) voidptr

pub fn adapter(monitor &glfw.Monitor) ?string {
	pointer := C.glfwGetWin32Adapter(monitor)
	if isnil(pointer) { return none }
	return unsafe { pointer.vstring() }.clone()
}

pub fn monitor(monitor &glfw.Monitor) ?string {
	pointer := C.glfwGetWin32Monitor(monitor)
	if isnil(pointer) { return none }
	return unsafe { pointer.vstring() }.clone()
}

pub fn window(window &glfw.Window) voidptr {
	return C.glfwGetWin32Window(window)
}

pub fn wgl_context(window &glfw.Window) voidptr {
	return C.glfwGetWGLContext(window)
}
