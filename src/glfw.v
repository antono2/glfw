module glfw

import vulkan as vk


pub const _true = 1
pub const _false = 0
pub const press = 1
pub const release = 0
pub const repeat = 2

pub const key_enter = 257
pub const key_escape = 256
pub const key_space = 32

pub const client_api = 0x00022001
pub const no_api = 0
pub const resizable = 0x00020003
pub const iconified = 0x00020002

pub type Window = C.GLFWwindow
@[typedef]
struct C.GLFWwindow{}

pub type Monitor = C.GLFWmonitor
@[typedef]
struct C.GLFWmonitor{}

fn C.glfwInit() i32
pub fn initialize() bool {
	return C.glfwInit() == _true
}

fn C.glfwTerminate()
pub fn terminate() {
	C.glfwTerminate()
}

fn C.glfwCreateWindow(width i32, height i32, title &char, monitor &Monitor, share &Window) &Window
pub fn create_window(width i32, height i32, title string, monitor &Monitor, share &Window) &Window {
	return C.glfwCreateWindow(width, height, title.str, monitor, share)
}

fn C.glfwDestroyWindow(window &Window)
pub fn destroy_window(window &Window){
  C.glfwDestroyWindow(window) 
}

fn C.glfwSetWindowUserPointer(window &Window, pointer voidptr)
pub fn set_window_user_pointer(window &Window, pointer voidptr) {
	C.glfwSetWindowUserPointer(window, pointer)
}

fn C.glfwGetWindowUserPointer(window &Window) voidptr
pub fn get_user_pointer(window &Window) voidptr {
	return C.glfwGetWindowUserPointer(window)
}

pub type GLFWFnKey = fn (window &Window, key_id i32, scan_code i32, action i32, bit_filed i32)

fn C.glfwSetKeyCallback(window &Window, callback GLFWFnKey)
pub fn set_key_callback(window &Window, callback GLFWFnKey) {
	C.glfwSetKeyCallback(window, callback)
}

fn C.glfwMakeContextCurrent(window &Window)
pub fn make_context_current(window &Window) {
	C.glfwMakeContextCurrent(window)
}

fn C.glfwVulkanSupported() i32
pub fn vulkan_supported() bool {
	return C.glfwVulkanSupported() == _true
}

fn C.glfwSetWindowShouldClose(window &Window, value i32)
pub fn set_should_close(window &Window, flag i32) {
	C.glfwSetWindowShouldClose(window, flag)
}

fn C.glfwWindowShouldClose(window &Window) i32
pub fn window_should_close(window &Window) bool {
	return C.glfwWindowShouldClose(window) == _true
}

fn C.glfwPollEvents()
pub fn poll_events() {
	C.glfwPollEvents()
}

fn C.glfwGetRequiredInstanceExtensions(count &u32) &&char
pub fn get_required_instance_extensions(count &u32) &&char {
	return C.glfwGetRequiredInstanceExtensions(count)
}

fn C.glfwCreateWindowSurface(instance vk.Instance, window &Window, allocator &vk.AllocationCallbacks, surface vk.SurfaceKHR) vk.Result
pub fn create_window_surface(instance vk.Instance, window &Window, allocator &vk.AllocationCallbacks, surface vk.SurfaceKHR) vk.Result {
	return C.glfwCreateWindowSurface(instance, window, allocator, surface)
}

fn C.glfwWindowHint(i32, i32)
pub fn window_hint(hint i32, value i32) {
	C.glfwWindowHint(hint, value)
}

fn C.glfwGetPhysicalDevicePresentationSupport(vk.Instance, vk.PhysicalDevice, u32) i32
pub fn get_physical_device_presentation_support(instance vk.Instance, device vk.PhysicalDevice, queuefamily u32) bool {
  return C.glfwGetPhysicalDevicePresentationSupport(instance, device, queuefamily) == _true
}

fn C.glfwGetKey(&Window, i32) i32
pub fn get_key(window &Window, key i32) i32 {
  return C.glfwGetKey(window, key)
}

pub type GLFWerrorfun = fn (error_code i32, const_description &char)

fn C.glfwSetErrorCallback(callback GLFWerrorfun) GLFWerrorfun 
pub fn set_error_callback(callback GLFWerrorfun) GLFWerrorfun
{
  return C.glfwSetErrorCallback(callback)
}

fn C.glfwGetFramebufferSize(window &Window, width &i32, height &i32)
pub fn get_framebuffer_size(window &Window, width &i32, height &i32) {
  C.glfwGetFramebufferSize(window, width, height)
}

fn C.glfwGetWindowAttrib(window &Window, attrib i32) i32
pub fn get_window_attrib(window &Window, attrib i32) i32 {
  return C.glfwGetWindowAttrib(window, attrib)
}

