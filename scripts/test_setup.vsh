// Check dependency requests before setup can reach native installers or builds.
import os
import time
import v.vmod

root := @VMODROOT
work := os.join_path(os.temp_dir(), 'glfw setup ${os.getpid()} ${time.sys_mono_now()}')
modules := os.join_path(work, 'modules')
log := os.join_path(work, 'command.tsv')
vulkan_setup := os.join_path(modules, 'antono2', 'vulkan', 'setup.vsh')
os.mkdir_all(os.dir(vulkan_setup))!
os.write_file(vulkan_setup, '// The fixture CLI stops before this script runs.\n')!
fake_source := os.join_path(work, 'fake_v.v')
os.write_file(fake_source, 'module main
import os
fn main() {
 os.write_file(os.getenv("GLFW_SETUP_COMMAND_LOG"), os.args[1..].join("\t")) or { panic(err) }
 exit(77)
}
')!
fake_cli := os.join_path(work, $if windows { 'v.exe' } $else { 'v' })
build :=
	os.execute('${os.quoted_path(@VEXE)} -o ${os.quoted_path(fake_cli)} ${os.quoted_path(fake_source)}')
assert build.exit_code == 0, build.output
mut original_env := map[string]string{}
for name in ['VMODULES', 'GLFW_SETUP_COMMAND_LOG', 'PATH'] {
	if value := os.getenv_opt(name) { original_env[name] = value }
}
defer {
	for name in ['VMODULES', 'GLFW_SETUP_COMMAND_LOG', 'PATH'] {
		if name in original_env {
			os.setenv(name, original_env[name], true)
		} else {
			os.unsetenv(name)
		}
	}
	os.rmdir_all(work) or { panic(err) }
}
os.setenv('VMODULES', modules, true)
os.setenv('GLFW_SETUP_COMMAND_LOG', log, true)
os.setenv('PATH', work + os.path_delimiter + os.getenv('PATH'), true)
profile := vmod.decode(os.read_file(os.join_path(root, 'v.mod'))!)!
assert profile.dependencies.len == 1
probe := os.join_path(work, $if windows { 'setup-probe.exe' } $else { 'setup-probe' })
for option in ['--install', '--check', '--unknown'] {
	os.write_file(log, '')!
	result := os.execute('${os.quoted_path(@VEXE)} -o ${os.quoted_path(probe)} run ${os.quoted_path(os.join_path(root,
		'setup.vsh'))} ${option}')
	command := os.read_file(log)!.split('\t')
	if option == '--unknown' {
		assert result.exit_code == 2, result.output
		assert os.read_file(log)! == ''
	} else {
		// Exit 77 proves setup stopped at the fixture, before any native side effects.
		assert result.exit_code != 0 && result.output.contains('command failed with exit code 77'), result.output
		if option == '--install' {
			assert command == ['install', profile.dependencies[0]], command.str()
		} else {
			assert command == ['run', vulkan_setup, '--check'], command.str()
		}
	}
}
println('Setup dependency pin, read-only routing and invalid option checks passed.')
