module egl

import antono2.glfw

#flag -DGLFW_EXPOSE_NATIVE_EGL
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

fn C.glfwGetEGLDisplay() voidptr
fn C.glfwGetEGLContext(&glfw.Window) voidptr
fn C.glfwGetEGLSurface(&glfw.Window) voidptr
fn C.glfwGetEGLConfig(&glfw.Window, &voidptr) i32

pub fn display() voidptr {
	return C.glfwGetEGLDisplay()
}

pub fn context(window &glfw.Window) voidptr {
	return C.glfwGetEGLContext(window)
}

pub fn surface(window &glfw.Window) voidptr {
	return C.glfwGetEGLSurface(window)
}

pub fn config(window &glfw.Window, value &voidptr) bool {
	return C.glfwGetEGLConfig(window, value) == glfw._true
}
