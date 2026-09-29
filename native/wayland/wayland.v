module wayland

import antono2.glfw

// Import only when the linked GLFW library was built with Wayland support.
#flag linux -DGLFW_EXPOSE_NATIVE_WAYLAND
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

fn C.glfwGetWaylandDisplay() voidptr
fn C.glfwGetWaylandMonitor(&glfw.Monitor) voidptr
fn C.glfwGetWaylandWindow(&glfw.Window) voidptr

pub fn display() voidptr {
	return C.glfwGetWaylandDisplay()
}

pub fn monitor(monitor &glfw.Monitor) voidptr {
	return C.glfwGetWaylandMonitor(monitor)
}

pub fn window(window &glfw.Window) voidptr {
	return C.glfwGetWaylandWindow(window)
}
