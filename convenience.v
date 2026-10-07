module glfw

// Convenience functions return owned V data where GLFW returns borrowed memory.

// Size holds width and height; units depend on the query that produced it.
pub struct Size {
pub:
	width  i32
	height i32
}

// window_size returns the content-area size in screen coordinates.
pub fn window_size(window &Window) Size {
	mut width := i32(0)
	mut height := i32(0)
	get_window_size(window, &width, &height)
	return Size{
		width:  width
		height: height
	}
}

// framebuffer_size returns the renderable framebuffer size in pixels.
pub fn framebuffer_size(window &Window) Size {
	mut width := i32(0)
	mut height := i32(0)
	get_framebuffer_size(window, &width, &height)
	return Size{
		width:  width
		height: height
	}
}

// window_title copies the title into a V string, or returns none for a null result.
pub fn window_title(window &Window) ?string {
	pointer := get_window_title(window)
	if isnil(pointer) {
		return none
	}
	return unsafe { pointer.vstring() }.clone()
}

// clipboard_text copies clipboard text, or returns none when GLFW supplies no string.
pub fn clipboard_text(window &Window) ?string {
	pointer := get_clipboard_string(window)
	if isnil(pointer) {
		return none
	}
	return unsafe { pointer.vstring() }.clone()
}

// set_clipboard_text passes a UTF-8 string to GLFW, which copies its contents.
pub fn set_clipboard_text(window &Window, value string) {
	set_clipboard_string(window, value.str)
}

// required_instance_extensions copies the Vulkan instance extension names.
// An empty result does not distinguish an error from no available extensions.
pub fn required_instance_extensions() []string {
	mut count := u32(0)
	pointers := get_required_instance_extensions(&count)
	mut result := []string{cap: int(count)}
	if isnil(pointers) {
		return result
	}
	for i in 0 .. int(count) {
		result << unsafe { pointers[i].vstring() }.clone()
	}
	return result
}

// monitor_names copies connected monitor names in GLFW enumeration order.
// Unavailable names become empty strings; an unavailable monitor list becomes an empty array.
pub fn monitor_names() []string {
	mut count := i32(0)
	monitors := get_monitors(&count)
	mut result := []string{cap: int(count)}
	if isnil(monitors) {
		return result
	}
	for i in 0 .. int(count) {
		name := get_monitor_name(unsafe { monitors[i] })
		if isnil(name) {
			result << ''
		} else {
			result << unsafe { name.vstring() }.clone()
		}
	}
	return result
}

// video_modes copies the available modes for monitor, or returns an empty array.
pub fn video_modes(monitor &Monitor) []VideoMode {
	mut count := i32(0)
	pointer := get_video_modes(monitor, &count)
	mut result := []VideoMode{cap: int(count)}
	if isnil(pointer) {
		return result
	}
	for i in 0 .. int(count) {
		result << unsafe { pointer[i] }
	}
	return result
}

// joystick_axes snapshots the current axes into a V-owned array.
pub fn joystick_axes(jid i32) []f32 {
	mut count := i32(0)
	pointer := get_joystick_axes(jid, &count)
	mut result := []f32{cap: int(count)}
	if isnil(pointer) {
		return result
	}
	for i in 0 .. int(count) {
		result << unsafe { pointer[i] }
	}
	return result
}

// joystick_buttons snapshots button states into a V-owned array.
pub fn joystick_buttons(jid i32) []u8 {
	mut count := i32(0)
	pointer := get_joystick_buttons(jid, &count)
	mut result := []u8{cap: int(count)}
	if isnil(pointer) {
		return result
	}
	for i in 0 .. int(count) {
		result << unsafe { pointer[i] }
	}
	return result
}

// joystick_hats snapshots hat bitmasks into a V-owned array.
pub fn joystick_hats(jid i32) []u8 {
	mut count := i32(0)
	pointer := get_joystick_hats(jid, &count)
	mut result := []u8{cap: int(count)}
	if isnil(pointer) {
		return result
	}
	for i in 0 .. int(count) {
		result << unsafe { pointer[i] }
	}
	return result
}

// Call this inside a drop callback to retain its paths after the callback ends.
pub fn copy_drop_paths(count i32, paths &&char) []string {
	mut result := []string{cap: int(count)}
	if isnil(paths) {
		return result
	}
	for i in 0 .. int(count) {
		result << unsafe { paths[i].vstring() }.clone()
	}
	return result
}

// create_window_checked creates a window or returns GLFW's error description.
// The caller must destroy a successful window before terminating GLFW.
pub fn create_window_checked(width i32, height i32, title string, monitor &Monitor, share &Window) !&Window {
	window := create_window(width, height, title, monitor, share)
	if isnil(window) {
		mut description := unsafe { &char(0) }
		code := get_error(&description)
		if !isnil(description) {
			return error('GLFW ${code}: ' + unsafe { description.vstring() }.clone())
		}
		return error('GLFW window creation failed (${code})')
	}
	return window
}

// create_windowed creates a windowed window without a shared OpenGL context.
// Uses the current window hints; the caller owns the returned window lifetime.
pub fn create_windowed(width i32, height i32, title string) !&Window {
	return create_window_checked(width, height, title, unsafe { nil }, unsafe { nil })
}
