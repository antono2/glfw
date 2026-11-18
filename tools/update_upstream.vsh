// Check the latest stable GLFW release and regenerate the vendored bindings.
import crypto.sha256
import flag
import x.json2
import net.http
import os
import strconv
import time
import tools.glfwgen

struct Release {
	tag_name   string
	draft      bool
	prerelease bool
}

fn certificate_bundle() string {
	if path := os.getenv_opt('SSL_CERT_FILE') {
		return path
	}
	for path in ['/etc/ssl/certs/ca-certificates.crt', '/etc/pki/tls/certs/ca-bundle.crt',
		'/etc/ssl/cert.pem'] {
		if os.is_file(path) {
			return path
		}
	}
	return ''
}

fn download(url string) !string {
	response := http.fetch(
		url:          url
		user_agent:   'antono2-glfw-updater'
		header:       http.new_header(key: .accept, value: 'application/vnd.github+json')
		validate:     true
		verify:       certificate_bundle()
		read_timeout: 30 * time.second
	)!
	if response.status_code != 200 {
		return error('GET ${url} returned HTTP ${response.status_code}')
	}
	return response.body
}

fn latest_tag() !string {
	release :=
		json2.decode[Release](download('https://api.github.com/repos/glfw/glfw/releases/latest')!)!
	if release.draft || release.prerelease {
		return error('GitHub’s latest release is not stable')
	}
	return release.tag_name
}

fn version_numbers(tag string) ![]int {
	parts := tag.split('.')
	if parts.len != 3 || parts.any(it == '' || !it.bytes().all(it.is_digit())) {
		return error('unsupported GLFW release tag: ${tag}')
	}
	mut numbers := []int{}
	for part in parts {
		numbers << int(strconv.parse_uint(part, 10, 31)!)
	}
	return numbers
}

fn newer(current []int, candidate []int) bool {
	for index, version in candidate {
		if version != current[index] {
			return version > current[index]
		}
	}
	return false
}

fn update(root string, tag string, pin glfwgen.Pin) ! {
	current := version_numbers(pin.version)!
	candidate := version_numbers(tag)!
	if !newer(current, candidate) {
		println('GLFW ${pin.version} is current')
		return
	}
	mut downloaded := map[string]string{}
	mut hashes := map[string]string{}
	for name in glfwgen.header_files {
		content :=
			download('https://raw.githubusercontent.com/glfw/glfw/${tag}/include/GLFW/${name}')!
		downloaded[name] = content
		hashes[name] = sha256.hexhash(content)
	}
	actual := glfwgen.header_version(downloaded['glfw3.h'])!
	if actual != tag {
		return error('release tag ${tag} does not match header version ${actual}')
	}
	for name in glfwgen.header_files {
		os.write_file(os.join_path(root, 'third_party', name), downloaded[name])!
	}
	next := glfwgen.Pin{
		version: tag
		tag:     tag
		headers: hashes
	}
	os.write_file(os.join_path(root, 'third_party', 'upstream.json'), json2.encode(next,
		prettify: true
	) + '\n')!

	mut review := []string{}
	if current[0] != candidate[0] {
		review << 'The major version changed and requires compatibility review.'
	}
	glfwgen.generate(root, @VEXE, false) or {
		review << 'Generation failed\n\n```text\n${err}\n```'
	}
	notes := os.join_path(root, 'UPSTREAM_UPDATE.md')
	if review.len > 0 {
		report := '# GLFW ${tag} update needs binding work\n\n' + review.join('\n\n') +
			'\n\nReview the ABI and public API, regenerate if needed and remove this file.\n'
		os.write_file(notes, report)!
		print(report)
	} else if os.exists(notes) {
		os.rm(notes)!
	}
}

fn run(args []string) ! {
	mut parser := flag.new_flag_parser(args)
	parser.application('update_upstream')
	parser.description('Update the vendored GLFW headers and generated V declarations.')
	tag_arg := parser.string('tag', 0, '', 'test a specific stable release tag')
	print_version := parser.bool('print-version', 0, false, 'show the currently pinned release')
	if parser.bool('help', `h`, false, 'show this help') {
		println(parser.usage())
		return
	}
	if parser.finalize()!.len != 0 {
		return error(parser.usage())
	}
	root := os.dir(@DIR)
	pin := glfwgen.read_pin(root)!
	if print_version {
		println(pin.version)
		return
	}
	tag := if tag_arg != '' { tag_arg } else { latest_tag()! }
	update(root, tag, pin)!
}

run(os.args[1..]) or {
	eprintln(err)
	exit(1)
}
