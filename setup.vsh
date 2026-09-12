#!/usr/bin/env -S v run

// Installs Vulkan first, then the native GLFW development package and this V
// module. Running without arguments installs; --check is read-only.

import os

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
		run('sudo apt-get install -y libglfw3-dev')!
		os.setenv('GLFW_INCLUDE', '/usr/include', true)
		os.setenv('GLFW_LIB', '/usr/lib/x86_64-linux-gnu', true)
		return
	}
	if command_exists('dnf') {
		run('sudo dnf install -y glfw-devel')!
		os.setenv('GLFW_INCLUDE', '/usr/include', true)
		os.setenv('GLFW_LIB', '/usr/lib64', true)
		return
	}
	if command_exists('pacman') {
		run('sudo pacman -S --needed --noconfirm glfw')!
		os.setenv('GLFW_INCLUDE', '/usr/include', true)
		os.setenv('GLFW_LIB', '/usr/lib', true)
		return
	}
	if command_exists('zypper') {
		run('sudo zypper --non-interactive install glfw-devel')!
		os.setenv('GLFW_INCLUDE', '/usr/include', true)
		os.setenv('GLFW_LIB', '/usr/lib64', true)
		return
	}
	return error('unsupported Linux package manager; install the GLFW development package and rerun with --check')
}

fn install_glfw_macos() ! {
	if !command_exists('brew') {
		return error('Homebrew is required for automatic GLFW setup: https://brew.sh')
	}
	run('brew install glfw')!
	prefix := os.execute('brew --prefix glfw')
	if prefix.exit_code == 0 {
		os.setenv('GLFW_INCLUDE', os.join_path(prefix.output.trim_space(), 'include'), true)
		os.setenv('GLFW_LIB', os.join_path(prefix.output.trim_space(), 'lib'), true)
	}
}

fn install_glfw_windows() ! {
	if !command_exists('git') {
		return error('Git is required; install it with `winget install --id Git.Git`')
	}
	cache_root := os.join_path(os.cache_dir(), 'antono2', 'glfw')
	vcpkg_root := os.join_path(cache_root, 'vcpkg')
	if !os.is_dir(vcpkg_root) {
		os.mkdir_all(cache_root)!
		run('git clone --depth 1 https://github.com/microsoft/vcpkg.git ${os.quoted_path(vcpkg_root)}')!
	}
	vcpkg := os.join_path(vcpkg_root, 'vcpkg.exe')
	if !os.is_file(vcpkg) {
		run(os.quoted_path(os.join_path(vcpkg_root, 'bootstrap-vcpkg.bat')))!
	}
	run('${os.quoted_path(vcpkg)} install glfw3:x64-windows')!
	sdk_root := os.join_path(vcpkg_root, 'installed', 'x64-windows')
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

fn main() {
	if os.args.len > 2 || (os.args.len == 2 && os.args[1] !in ['--install', '--check', '-h', '--help']) {
		eprintln('Usage: v run setup.vsh [--install|--check]')
		exit(2)
	}
	if os.args.len == 2 && os.args[1] in ['-h', '--help'] {
		println('Usage: v run setup.vsh [--install|--check]\n\nDefault: install Vulkan, GLFW, and the V modules.\n--check: perform read-only prerequisite and compile checks.')
		return
	}
	install := os.args.len == 1 || os.args[1] == '--install'
	if install {
		run('v install antono2.vulkan') or { panic(err) }
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
	project_dir := os.dir(os.real_path(@FILE))
	run('v -check-syntax ${os.quoted_path(project_dir)}') or { panic(err) }
	println('\nGLFW/Vulkan prerequisites and compile checks are ready.')
}
