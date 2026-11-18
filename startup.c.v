// Opt-in startup mapping; raw generated GLFW operations retain their semantics.
module glfw

#flag -I @VMODROOT/c
#flag linux -ldl
#include "window_startup.h"

fn C.a2_glfw_show_startup(&Window, &char, usize) int

// show_window_and_wait maps a window before its renderer starts presenting.
// Create it with window_hint(visible, 0) so creation itself does not wait inside
// GLFW's synchronous X11 show. Hidden, non-minimized X11 windows are retried for
// up to five seconds. The caller retains ownership, including on failure.
pub fn show_window_and_wait(window &Window) ! {
	mut message := [256]char{}
	if C.a2_glfw_show_startup(window, &message[0], usize(message.len)) == 0 {
		return error(unsafe { cstring_to_vstring(&message[0]) }.clone())
	}
}
