// Checks public ABI types, the linked GLFW version and headless window helpers.
// Uses GLFW's null platform so window tests do not require a display server.
module glfw

fn test_public_constants_and_types_compile() {
	assert _true == 1
	assert _false == 0
	assert press == 1
	assert release == 0
	assert repeat == 2
	assert no_api == 0
}

fn test_linked_glfw_version() {
	mut major := i32(0)
	mut minor := i32(0)
	mut revision := i32(0)
	get_version(&major, &minor, &revision)
	assert major == 3
	assert minor > 5 || (minor == 5 && revision >= 1)
}

fn size_callback(window &Window, width i32, height i32) {
	_ = window
	_ = width
	_ = height
}

fn test_null_platform_window_and_convenience() {
	init_hint(platform, platform_null)
	assert initialize()
	defer {
		terminate()
	}
	assert get_platform() == platform_null
	monitor := get_primary_monitor()
	assert !isnil(monitor)
	assert video_modes(monitor).len > 0
	assert monitor_names().len > 0
	window_hint(client_api, no_api)
	window := create_window_checked(320, 240, 'binding test', unsafe { nil }, unsafe { nil }) or {
		panic(err)
	}
	defer {
		destroy_window(window)
	}
	assert window_size(window) == Size{
		width:  320
		height: 240
	}
	assert framebuffer_size(window) == Size{
		width:  320
		height: 240
	}
	assert window_title(window) or { '' } == 'binding test'
	set_window_size_callback(window, size_callback)
	set_window_size(window, 640, 480)
	assert window_size(window) == Size{
		width:  640
		height: 480
	}
	mut state := GamepadState{}
	assert get_gamepad_state(0, &state) == _false
	assert joystick_axes(0).len == 0
	assert joystick_buttons(0).len == 0
	assert joystick_hats(0).len == 0
	poll_events()
}

fn test_checked_creation_reports_glfw_error() {
	init_hint(platform, platform_null)
	assert initialize()
	defer {
		terminate()
	}
	create_windowed(0, 0, 'invalid') or {
		assert err.msg().contains('GLFW')
		return
	}
	assert false
}
