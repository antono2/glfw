#!/usr/bin/env -S v run

// Installs Vulkan first, then the native GLFW development package and this V
// module. Running without arguments installs; --check is read-only.

import os
fn glfw_version() string {
	contents := os.read_file(os.join_path(os.dir(os.real_path(@FILE)), 'third_party', 'upstream.json')) or { panic(err) }
	for line in contents.split_into_lines() {
		entry := line.trim_space()
		if entry.starts_with('"version":') {
			return entry.all_after(':').trim_space().trim('" ,')
		}
	}
	panic('third_party/upstream.json has no version')
}

fn command_exists(name string) bool {
	os.find_abs_path_of_executable(name) or { return false }
	return true
}

fn run(command string) ! {
	println('\n> ${command}')
	result := os.execute(command)
	if result.output.trim_space() != '' {
		println(result.output.trim_right('\r\n'))
	}
	if result.exit_code != 0 {
		return error('command failed with exit code ${result.exit_code}')
	}
}

fn install_glfw_linux() ! {
	if command_exists('apt-get') {
		run('sudo apt-get install -y cmake git libglfw3-dev libwayland-dev libxkbcommon-dev wayland-protocols libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev')!
	} else if command_exists('dnf') {
		run('sudo dnf install -y cmake git glfw-devel wayland-devel libxkbcommon-devel wayland-protocols-devel')!
	} else if command_exists('pacman') {
		run('sudo pacman -S --needed --noconfirm cmake git glfw wayland libxkbcommon wayland-protocols')!
	} else if command_exists('zypper') {
		run('sudo zypper --non-interactive install cmake git glfw-devel wayland-devel libxkbcommon-devel wayland-protocols-devel')!
	} else {
		return error('unsupported Linux package manager; install GLFW ${glfw_version()} and rerun with --check')
	}
	cache_root := os.join_path(os.cache_dir(), 'antono2', 'glfw', glfw_version())
	source := os.join_path(cache_root, 'source')
	build := os.join_path(cache_root, 'build')
	install := os.join_path(cache_root, 'install')
	os.mkdir_all(cache_root)!
	if !os.is_dir(source) {
		run('git clone --depth 1 --branch ${glfw_version()} https://github.com/glfw/glfw.git ${os.quoted_path(source)}')!
	}
	run('cmake -S ${os.quoted_path(source)} -B ${os.quoted_path(build)} -DCMAKE_INSTALL_PREFIX=${os.quoted_path(install)} -DBUILD_SHARED_LIBS=ON -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF -DGLFW_BUILD_WAYLAND=ON')!
	run('cmake --build ${os.quoted_path(build)} --parallel')!
	run('cmake --install ${os.quoted_path(build)}')!
	os.setenv('GLFW_INCLUDE', os.join_path(install, 'include'), true)
	os.setenv('GLFW_LIB', os.join_path(install, 'lib'), true)
	os.setenv('LD_LIBRARY_PATH', os.join_path(install, 'lib') + ':' + os.getenv('LD_LIBRARY_PATH'), true)
}

fn install_glfw_macos() ! {
	if !command_exists('brew') {
		return error('Homebrew is required for automatic GLFW setup: https://brew.sh')
	}
	if !command_exists('cmake') {
		run('brew install cmake')!
	}
	cache_root := os.join_path(os.cache_dir(), 'antono2', 'glfw', glfw_version())
	source := os.join_path(cache_root, 'source')
	build := os.join_path(cache_root, 'build')
	install := os.join_path(cache_root, 'install')
	if !os.is_dir(source) {
		os.mkdir_all(cache_root)!
		run('git clone --depth 1 --branch ${glfw_version()} https://github.com/glfw/glfw.git ${os.quoted_path(source)}')!
	}
	run('cmake -S ${os.quoted_path(source)} -B ${os.quoted_path(build)} -DCMAKE_INSTALL_PREFIX=${os.quoted_path(install)} -DBUILD_SHARED_LIBS=ON -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF')!
	run('cmake --build ${os.quoted_path(build)} --parallel')!
	run('cmake --install ${os.quoted_path(build)}')!
	os.setenv('GLFW_INCLUDE', os.join_path(install, 'include'), true)
	os.setenv('GLFW_LIB', os.join_path(install, 'lib'), true)
	os.setenv('DYLD_LIBRARY_PATH', os.join_path(install, 'lib') + ':' + os.getenv('DYLD_LIBRARY_PATH'), true)
}

fn install_glfw_windows() ! {
	if !command_exists('git') {
		return error('Git is required; install it with `winget install --id Git.Git`')
	}
	if !command_exists('cmake') {
		return error('CMake is required to build GLFW ${glfw_version()}')
	}
	cache_root := os.join_path(os.cache_dir(), 'antono2', 'glfw', glfw_version())
	source := os.join_path(cache_root, 'source')
	build := os.join_path(cache_root, 'build')
	sdk_root := os.join_path(cache_root, 'install')
	if !os.is_dir(source) {
		os.mkdir_all(cache_root)!
		run('git clone --depth 1 --branch ${glfw_version()} https://github.com/glfw/glfw.git ${os.quoted_path(source)}')!
	}
	run('cmake -S ${os.quoted_path(source)} -B ${os.quoted_path(build)} -DCMAKE_INSTALL_PREFIX=${os.quoted_path(sdk_root)} -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL -DGLFW_BUILD_EXAMPLES=OFF -DGLFW_BUILD_TESTS=OFF -DGLFW_BUILD_DOCS=OFF')!
	run('cmake --build ${os.quoted_path(build)} --config Release --parallel')!
	run('cmake --install ${os.quoted_path(build)} --config Release')!
	include_dir := os.join_path(sdk_root, 'include')
	lib_dir := os.join_path(sdk_root, 'lib')
	os.setenv('GLFW_INCLUDE', include_dir, true)
	os.setenv('GLFW_LIB', lib_dir, true)
	run('setx GLFW_INCLUDE ${os.quoted_path(include_dir)}')!
	run('setx GLFW_LIB ${os.quoted_path(lib_dir)}')!
	vulkan_sdk := os.execute('powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable(\'VULKAN_SDK\', \'Machine\')"')
	if vulkan_sdk.exit_code == 0 && vulkan_sdk.output.trim_space() != '' {
		os.setenv('VULKAN_SDK', vulkan_sdk.output.trim_space(), true)
	}
}

fn installed_vulkan_setup() string {
	return os.join_path(os.vmodules_dir(), 'antono2', 'vulkan', 'setup.vsh')
}

fn find_glfw_header() string {
	mut roots := []string{}
	if include_dir := os.getenv_opt('GLFW_INCLUDE') {
		roots << include_dir
	}
	$if !windows {
		roots << ['/usr/include', '/usr/local/include', '/opt/homebrew/include']
	}
	for root in roots {
		candidate := os.join_path(root, 'GLFW', 'glfw3.h')
		if os.is_file(candidate) {
			return candidate
		}
	}
	return ''
}

fn check_glfw_header_version(path string) ! {
	contents := os.read_file(path)!
	mut major := -1
	mut minor := -1
	mut revision := -1
	for line in contents.split_into_lines() {
		fields := line.fields()
		if fields.len < 3 || fields[0] != '#define' {
			continue
		}
		match fields[1] {
			'GLFW_VERSION_MAJOR' { major = fields[2].int() }
			'GLFW_VERSION_MINOR' { minor = fields[2].int() }
			'GLFW_VERSION_REVISION' { revision = fields[2].int() }
			else {}
		}
	}
	required := glfw_version().split('.').map(it.int())
	if required.len != 3 || major != required[0] || minor < required[1] || (minor == required[1] && revision < required[2]) {
		return error('GLFW ${glfw_version()} or newer compatible headers are required; found ${major}.${minor}.${revision} at ${path}')
	}
}

fn main() {
	if os.args.len > 2 || (os.args.len == 2 && os.args[1] !in ['--install', '--check', '-h', '--help']) {
		eprintln('Usage: v run setup.vsh [--install|--check]')
		exit(2)
	}
	if os.args.len == 2 && os.args[1] in ['-h', '--help'] {
		println('Usage: v run setup.vsh [--install|--check]\n\nDefault: install Vulkan, GLFW and the V modules.\n--check: perform read-only prerequisite and compile checks.')
		return
	}
	install := os.args.len == 1 || os.args[1] == '--install'
	if install {
		run('v install antono2.vulkan@v3.2.0') or { panic(err) }
	}
	vulkan_setup := installed_vulkan_setup()
	if !os.is_file(vulkan_setup) {
		eprintln('antono2.vulkan does not include setup.vsh; install or update antono2.vulkan first')
		exit(1)
	}
	mode := if install { '--install' } else { '--check' }
	run('v run ${os.quoted_path(vulkan_setup)} ${mode}') or { panic(err) }
	if install {
		$if linux {
			install_glfw_linux() or { panic(err) }
		} $else $if macos {
			install_glfw_macos() or { panic(err) }
		} $else $if windows {
			install_glfw_windows() or { panic(err) }
		} $else {
			eprintln('Automatic GLFW installation is unsupported on this operating system.')
			exit(1)
		}
		run('v install antono2.glfw') or { panic(err) }
	}
	header := find_glfw_header()
	if header == '' {
		eprintln('[missing] GLFW development headers')
		exit(1)
	}
	println('[ok]       GLFW header: ${header}')
	check_glfw_header_version(header) or { panic(err) }
	project_dir := os.dir(os.real_path(@FILE))
	$if windows {
		// The installed glfw3.lib is built for MSVC, while V defaults to TCC/GCC.
		// CI runs the linked tests from a configured Visual Studio environment.
		run('v -check-syntax ${os.quoted_path(project_dir)}') or { panic(err) }
	} $else {
		run('v test ${os.quoted_path(project_dir)}') or { panic(err) }
	}
	println('\nGLFW/Vulkan prerequisites and compile checks are ready.')
	if install {
		$if linux {
			println('For later shells, export GLFW_INCLUDE=${os.getenv('GLFW_INCLUDE')}, GLFW_LIB=${os.getenv('GLFW_LIB')}, and add GLFW_LIB to LD_LIBRARY_PATH.')
		}
	}
}
