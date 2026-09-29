module osmesa

import antono2.glfw

#flag -DGLFW_EXPOSE_NATIVE_OSMESA
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

fn C.glfwGetOSMesaColorBuffer(&glfw.Window, &i32, &i32, &i32, &voidptr) i32
fn C.glfwGetOSMesaDepthBuffer(&glfw.Window, &i32, &i32, &i32, &voidptr) i32
fn C.glfwGetOSMesaContext(&glfw.Window) voidptr

pub fn color_buffer(window &glfw.Window, width &i32, height &i32, format &i32, buffer &voidptr) bool {
	return C.glfwGetOSMesaColorBuffer(window, width, height, format, buffer) == glfw._true
}

pub fn depth_buffer(window &glfw.Window, width &i32, height &i32, bytes_per_value &i32, buffer &voidptr) bool {
	return C.glfwGetOSMesaDepthBuffer(window, width, height, bytes_per_value, buffer) == glfw._true
}

pub fn context(window &glfw.Window) voidptr {
	return C.glfwGetOSMesaContext(window)
}
