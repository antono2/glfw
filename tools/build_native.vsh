// Build the pinned GLFW release and expose it to later CI steps.
import flag
import os
import tools.glfwgen

fn command(args []string) !string {
	result := os.exec(args)
	if result.exit_code != 0 {
		return error('${args[0]} exited with status ${result.exit_code}\n${result.output}')
	}
	return result.output
}

fn build(args []string) ! {
	mut parser := flag.new_flag_parser(args)
	parser.application('build_native')
	parser.description('Build the pinned shared GLFW library on Linux or macOS.')
	work_arg := parser.string('work-dir', 0, os.getenv('RUNNER_TEMP'),
		'parent directory for the checkout and install')
	env_path := parser.string('github-env', 0, os.getenv('GITHUB_ENV'),
		'optional GitHub Actions environment file')
	if parser.bool('help', `h`, false, 'show this help') {
		println(parser.usage())
		return
	}
	if parser.finalize()!.len != 0 || work_arg == '' {
		return error(parser.usage())
	}
	platform := os.user_os()
	if platform !in ['linux', 'macos'] {
		return error('this native build supports Linux and macOS')
	}
	root := os.dir(@DIR)
	version := glfwgen.read_pin(root)!.version
	work := os.abs_path(work_arg)
	prefix := os.join_path(work, 'glfw-${version}')
	source := prefix + '-source'
	os.mkdir_all(work)!
	command(['git', 'clone', '--depth', '1', '--branch', version, 'https://github.com/glfw/glfw.git',
		source])!
	build_path := os.join_path(source, 'build')
	mut configure := ['cmake', '-S', source, '-B', build_path, '-DCMAKE_INSTALL_PREFIX=${prefix}',
		'-DBUILD_SHARED_LIBS=ON', '-DGLFW_BUILD_EXAMPLES=OFF', '-DGLFW_BUILD_TESTS=OFF',
		'-DGLFW_BUILD_DOCS=OFF']
	if platform == 'linux' {
		configure << '-DGLFW_BUILD_WAYLAND=ON'
	}
	command(configure)!
	command(['cmake', '--build', build_path, '--parallel'])!
	command(['cmake', '--install', build_path])!
	library := os.join_path(prefix, 'lib')
	mut values := ['GLFW_INCLUDE=${os.join_path(prefix, 'include')}', 'GLFW_LIB=${library}']
	if platform == 'linux' {
		values << 'LD_LIBRARY_PATH=${library}'
	} else {
		vulkan := command(['brew', '--prefix', 'vulkan-loader'])!.trim_space()
		values << ['DYLD_LIBRARY_PATH=${library}', 'VULKAN_SDK=${vulkan}']
	}
	output := values.join('\n') + '\n'
	if env_path != '' {
		mut file := os.open_append(env_path)!
		defer { file.close() }
		file.write_string(output)!
	}
	print(output)
}

build(os.args[1..]) or {
	eprintln(err)
	exit(1)
}
