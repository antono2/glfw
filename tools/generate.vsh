// Verify or regenerate the V API from the vendored GLFW headers.
import flag
import os
import tools.glfwgen

fn run(args []string) ! {
	mut parser := flag.new_flag_parser(args)
	parser.application('generate')
	parser.description('Generate the V API from the pinned GLFW headers.')
	check := parser.bool('check', 0, false, 'verify the committed output')
	if parser.bool('help', `h`, false, 'show this help') {
		println(parser.usage())
		return
	}
	if parser.finalize()!.len != 0 {
		return error(parser.usage())
	}
	glfwgen.generate(os.dir(@DIR), @VEXE, check)!
}

run(os.args[1..]) or {
	eprintln(err)
	exit(1)
}
