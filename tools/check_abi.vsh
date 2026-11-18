// Compile and link every generated core wrapper without calling GLFW.
import flag
import os
import tools.glfwgen

fn run(args []string) ! {
	mut parser := flag.new_flag_parser(args)
	parser.application('check_abi')
	parser.description('Compile and link the generated GLFW wrappers.')
	cc := parser.string('cc', 0, 'gcc', 'C compiler for the ABI probe')
	if parser.bool('help', `h`, false, 'show this help') {
		println(parser.usage())
		return
	}
	if parser.finalize()!.len != 0 {
		return error(parser.usage())
	}
	root := os.dir(@DIR)
	source, count := glfwgen.abi_probe(root)!
	directory := glfwgen.temporary_directory('glfw-abi')!
	defer { os.rmdir_all(directory) or {} }
	binding := os.join_path(directory, 'antono2', 'glfw')
	os.mkdir_all(binding)!
	for name in os.ls(root)! {
		if name.ends_with('.v') || name == 'v.mod' {
			os.cp(os.join_path(root, name), os.join_path(binding, name))!
		}
	}
	os.cp_all(os.join_path(root, 'c'), os.join_path(binding, 'c'), true)!
	probe := os.join_path(directory, 'abi_probe.v')
	os.write_file(probe, source)!
	// Use the selected source checkout even when another binding is installed.
	result := os.exec([@VEXE, '-path', '${directory}|@vlib|@vmodules', '-cc', cc, 'run', probe])
	if result.exit_code != 0 {
		return error('GLFW ABI probe failed\n${result.output}')
	}
	println('Compiled and linked ${count} generated GLFW calls')
}

run(os.args[1..]) or {
	eprintln(err)
	exit(1)
}
