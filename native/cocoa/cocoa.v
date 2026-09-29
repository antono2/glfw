module cocoa

import antono2.glfw

#flag darwin -DGLFW_EXPOSE_NATIVE_COCOA
#flag darwin -DGLFW_EXPOSE_NATIVE_NSGL
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

fn C.glfwGetCocoaMonitor(&glfw.Monitor) u32
fn C.glfwGetCocoaWindow(&glfw.Window) voidptr
fn C.glfwGetCocoaView(&glfw.Window) voidptr
fn C.glfwGetNSGLContext(&glfw.Window) voidptr

pub fn monitor(monitor &glfw.Monitor) u32 {
	return C.glfwGetCocoaMonitor(monitor)
}

pub fn window(window &glfw.Window) voidptr {
	return C.glfwGetCocoaWindow(window)
}

pub fn view(window &glfw.Window) voidptr {
	return C.glfwGetCocoaView(window)
}

pub fn nsgl_context(window &glfw.Window) voidptr {
	return C.glfwGetNSGLContext(window)
}
