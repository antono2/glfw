// Compile the binding's actual environment flags with native paths containing spaces.
import os

fn check() ! {
	root := os.dir(@DIR)
	work := os.join_path(os.vtmp_dir(), 'glfw flag paths ${os.getpid()}')
	os.mkdir(work)!
	defer { os.rmdir_all(work) or {} }
	header := os.read_file(os.join_path(root, 'c', 'header.c.v'))!
	flags := header.split_into_lines().filter(it.starts_with('#flag -I') || it.starts_with('#flag -L'))
	assert flags.len == 2
	os.write_file(os.join_path(work, 'fixture.h'), 'static int fixture_value(void) { return 17; }\n')!
	source := os.join_path(work, 'probe.v')
	os.write_file(source, 'module main\n' + flags.join('\n') + '\n#include <fixture.h>\nfn C.fixture_value() i32\nfn main() { assert C.fixture_value() == 17 }\n')!
	os.setenv('GLFW_INCLUDE', work, true)
	os.setenv('GLFW_LIB', work, true)
	mut args := ['run', source]
	$if windows {
		args = ['-cc', 'msvc', ...args]
	}
	mut process := os.new_process(@VEXE)
	process.set_args(args)
	process.run()
	process.wait()
	code := process.code
	process.close()
	if code != 0 { return error('Native paths with spaces failed: ${code}') }
	println('Passed native flag paths with spaces')
}

check() or {
	eprintln(err)
	exit(1)
}
