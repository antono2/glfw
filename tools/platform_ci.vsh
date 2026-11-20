// Run GLFW compatibility, compiler, native API, and window startup checks.
import os

fn checked(args []string) ! {
	result := os.exec(args)
	print(result.output)
	if result.exit_code != 0 {
		return error('${args.join(' ')} exited with status ${result.exit_code}.')
	}
}

fn compiler(args []string) ! {
	mut call := [@VEXE]
	call << args
	checked(call)!
}

fn env_required(name string) !string {
	value := os.getenv(name)
	if value == '' {
		return error('${name} is required for this CI stage.')
	}
	return value
}

fn compatibility(publication bool) ! {
	compiler(['run', 'scripts/compatibility.vsh', '--self-test'])!
	if publication {
		compiler(['run', 'tools/publish_generated_branch.vsh', '--self-test'])!
	}
	compiler(['run', 'scripts/doctor.vsh', '--self-test'])!
	compiler(['run', 'scripts/compatibility.vsh', '--github-output', env_required('GITHUB_OUTPUT')!])!
}

fn platform_checks() ! {
	platform, compilers := match os.user_os() {
		'linux' { 'linux', ['gcc', 'tcc'] }
		'macos' { 'macos', ['clang'] }
		'windows' { 'windows', ['msvc'] }
		else { return error('Unsupported GLFW test platform.') }
	}

	compiler(['run', 'tools/generate.vsh', '--check'])!
	if platform != 'windows' {
		compiler(['run', 'setup.vsh', '--check'])!
	}
	for cc in compilers {
		compiler(['-cc', cc, 'test', '.'])!
	}
	compiler(['run', 'tools/check_abi.vsh', '--cc', compilers[0]])!
	compiler(['-cc', compilers[0], 'run', 'examples/native_${platform}_smoke.v'])!
}

fn window_startup() ! {
	temporary := env_required('RUNNER_TEMP')!
	probe := os.join_path(temporary, 'window-startup-probe')
	check := os.join_path(temporary, 'window-startup-check')
	logs := os.join_path(temporary, 'window-startup-logs')
	compiler(['-cc', 'tcc', '-o', probe, 'examples/window_startup.v'])!
	compiler(['-cc', 'tcc', '-o', check, 'tests/window_startup.v'])!
	os.setenv('VIMGUI_STARTUP_LOCAL_XLIB', '1', true)
	checked([check, probe, logs])!
}

fn build_master() ! {
	directory := os.abs_path(os.join_path('toolchain', 'v'))
	checked(['make', '-C', directory, 'VEXE=./v'])!
	mut file := os.open_append(env_required('GITHUB_PATH')!)!
	defer { file.close() }
	file.writeln(directory)!
}

fn run(args []string) ! {
	os.unsetenv('VEXE')
	if args == ['build-master'] {
		build_master()!
		return
	}
	os.chdir(os.dir(@DIR))!
	match args {
		['compatibility'] { compatibility(false)! }
		['compatibility-publication'] { compatibility(true)! }
		['platform-checks'] { platform_checks()! }
		['window-startup'] { window_startup()! }
		else { return error('Expected a GLFW CI stage.') }
	}
}

run(os.args[1..]) or {
	eprintln(err)
	exit(1)
}
