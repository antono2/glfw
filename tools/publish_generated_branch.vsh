// Publish staged generated files only when their Git tree changed.
import flag
import os
import rand
import tools.glfwgen

const bot_name = 'github-actions[bot]'
const bot_email = '41898282+github-actions[bot]@users.noreply.github.com'
const workflow_branch = 'automation/glfw-upstream'
const workflow_body = 'Automated upstream header and binding update. Review ABI and convenience behavior before merging. If UPSTREAM_UPDATE.md exists, generation needs manual work.'

struct Proposal {
	ref      string
	expected string
	needed   bool
}

fn git(repo string, args []string) !string {
	mut invocation := ['git', '-C', repo]
	invocation << args
	result := os.exec(invocation)
	if result.exit_code != 0 {
		return error('git ${args[0]} failed: ${result.output.trim_space()}')
	}
	return result.output.trim_space()
}

fn remote_head(repo string, ref string) !string {
	// An absent ref gives an empty result; network and auth failures still fail.
	reply := git(repo, ['ls-remote', '--heads', 'origin', ref])!
	return reply.fields()[0] or { '' }
}

fn plan_proposal(repo string, branch string) !Proposal {
	ref := 'refs/heads/' + branch
	git(repo, ['check-ref-format', ref])!
	expected := remote_head(repo, ref)!
	desired_tree := git(repo, ['write-tree'])!
	if expected != '' {
		git(repo, ['fetch', '--no-tags', 'origin', ref])!
		if git(repo, ['rev-parse', 'FETCH_HEAD'])! != expected {
			return error('Proposal moved during comparison; retry later')
		}
		if git(repo, ['rev-parse', expected + '^{tree}'])! == desired_tree {
			println('Generated files already match the existing proposal; no commit or push.')
			return Proposal{
				ref:      ref
				expected: expected
			}
		}
	}
	if git(repo, ['rev-parse', 'HEAD^{tree}'])! == desired_tree {
		println('Generated files already match the default branch; no commit or push.')
		return Proposal{}
	}
	return Proposal{
		ref:      ref
		expected: expected
		needed:   true
	}
}

fn apply_proposal(repo string, proposal Proposal, message string) !bool {
	if !proposal.needed {
		return false
	}
	git(repo, ['-c', 'user.name=' + bot_name, '-c', 'user.email=' + bot_email, 'commit', '-m',
		message])!
	// Even creation requires a lease: an empty expected revision means absent.
	git(repo, ['push', '--force-with-lease=${proposal.ref}:${proposal.expected}', 'origin',
		'HEAD:' + proposal.ref])!
	return true
}

fn publish(repo string, branch string, message string) !bool {
	return apply_proposal(repo, plan_proposal(repo, branch)!, message)
}

type GitHubCommand = fn ([]string) !string

fn github(args []string) !string {
	mut invocation := ['gh']
	invocation << args
	result := os.exec(invocation)
	if result.exit_code != 0 {
		return error('gh ${args.join(' ')} failed: ${result.output.trim_space()}')
	}
	return result.output.trim_space()
}

fn propose_staged(repo string, base string, version string, gh GitHubCommand) ! {
	if git(repo, ['rev-parse', 'HEAD^{tree}'])! == git(repo, ['write-tree'])! {
		println('No new GLFW release.')
		return
	}
	message := 'Update GLFW to ${version}'
	proposal := plan_proposal(repo, workflow_branch)!
	pushed := apply_proposal(repo, proposal, message)!
	open := gh(['pr', 'list', '--base', base, '--head', workflow_branch, '--state', 'open', '--json',
		'number', '--jq', '.[0].number // empty'])!
	if open == '' {
		expected := if pushed { git(repo, ['rev-parse', 'HEAD'])! } else { proposal.expected }
		if expected == '' || remote_head(repo, proposal.ref)! != expected {
			return error('Proposal moved before opening the draft. Retry later.')
		}
		println(gh(['pr', 'create', '--draft', '--base', base, '--head', workflow_branch, '--title',
			message, '--body', workflow_body])!)
	}
	// Repository-token updates do not run the pull-request checks automatically.
	if pushed || open == '' {
		gh(['workflow', 'run', 'test.yml', '--ref', workflow_branch])!
	}
}

fn propose_workflow(repo string, base string) ! {
	if base == '' {
		return error('DEFAULT_BRANCH is required in proposal mode.')
	}
	if git(repo, ['status', '--porcelain'])! == '' {
		println('No new GLFW release.')
		return
	}
	pin := glfwgen.read_pin(repo)!
	git(repo, ['checkout', '-B', workflow_branch])!
	stage_generated(repo)!
	propose_staged(repo, base, pin.version, github)!
}

fn stage_generated(repo string) ! {
	// V keeps the running script's executable beside its source. Only stage
	// updater outputs so that executable and unrelated files cannot enter a PR.
	mut paths := []string{}
	for path in ['third_party/glfw3.h', 'third_party/glfw3native.h', 'third_party/upstream.json',
		'glfw_generated.v', 'UPSTREAM_UPDATE.md'] {
		if os.exists(os.join_path(repo, path)) || git(repo, ['ls-files', '--', path])! != '' {
			paths << path
		}
	}
	if paths.len > 0 {
		mut args := ['add', '-A', '--']
		args << paths
		git(repo, args)!
	}
}

fn test_generated_scope(directory string) ! {
	repo := os.join_path(directory, 'generated scope')
	os.mkdir_all(os.join_path(repo, 'third_party'))!
	os.mkdir_all(os.join_path(repo, 'tools'))!
	git(repo, ['init', '--initial-branch=master'])!
	git(repo, ['config', 'user.name', 'Fixture'])!
	git(repo, ['config', 'user.email', 'fixture@example.invalid'])!
	git(repo, ['config', 'commit.gpgsign', 'false'])!
	os.write_file(os.join_path(repo, 'glfw_generated.v'), 'old bindings\n')!
	os.write_file(os.join_path(repo, 'UPSTREAM_UPDATE.md'), 'old review notes\n')!
	git(repo, ['add', '-A'])!
	git(repo, ['commit', '-m', 'base'])!
	// A running V script has an adjacent executable until it exits.
	os.write_file(os.join_path(repo, 'tools', 'publish_generated_branch'), 'executable fixture\n')!
	os.write_file(os.join_path(repo, 'unrelated.txt'), 'unrelated fixture\n')!
	stage_generated(repo)!
	assert git(repo, ['diff', '--cached', '--name-only'])! == ''
	os.write_file(os.join_path(repo, 'glfw_generated.v'), 'new bindings\n')!
	os.write_file(os.join_path(repo, 'third_party', 'glfw3.h'), 'new header\n')!
	os.write_file(os.join_path(repo, 'third_party', 'glfw3native.h'), 'new native header\n')!
	os.write_file(os.join_path(repo, 'third_party', 'upstream.json'), '{}\n')!
	os.rm(os.join_path(repo, 'UPSTREAM_UPDATE.md'))!
	stage_generated(repo)!
	assert git(repo, ['diff', '--cached', '--name-only'])!.split_into_lines() == [
		'UPSTREAM_UPDATE.md',
		'glfw_generated.v',
		'third_party/glfw3.h',
		'third_party/glfw3native.h',
		'third_party/upstream.json',
	]
}

fn write_output(path string, pushed bool) ! {
	if path != '' {
		mut stream := os.open_append(path)!
		defer { stream.close() }
		stream.writeln('pushed=${pushed}')!
	}
}

fn stage(repo string, text string) ! {
	os.write_file(os.join_path(repo, 'generated.txt'), text)!
	git(repo, ['add', '--', 'generated.txt'])!
}

fn expect_rejected_lease(repo string, proposal Proposal, message string) ! {
	apply_proposal(repo, proposal, message) or {
		if err.msg().contains('stale info') {
			return
		}
		return err
	}
	return error('Concurrent remote branch update was overwritten')
}

fn test_proposal_workflow(repo string, directory string, base string) ! {
	request := os.join_path(directory, 'open-request')
	events := os.join_path(directory, 'workflow-events')
	os.write_file(events, '')!
	gh := fn [request, events] (args []string) !string {
		if args[..2] == ['pr', 'list'] {
			assert args[2..8] == ['--base', 'master', '--head', workflow_branch, '--state', 'open']
			return os.read_file(request) or { '' }
		}
		mut log := os.open_append(events)!
		defer { log.close() }
		match args[..2] {
			['pr', 'create'] {
				assert args[2..7] == ['--draft', '--base', 'master', '--head', workflow_branch]
				assert args[7..9] == ['--title', 'Update GLFW to 3.5.0']
				os.write_file(request, '42')!
				log.writeln('draft')!
			}
			['workflow', 'run'] {
				assert args[2..] == ['test.yml', '--ref', workflow_branch]
				log.writeln('CI')!
			}
			else {
				return error('Unexpected GitHub command: ${args}')
			}
		}

		return ''
	}
	// Reset only the disposable repository created by self_test.
	git(repo, ['checkout', '--force', '--detach', base])!
	ref := 'refs/heads/' + workflow_branch
	propose_staged(repo, 'master', '3.5.0', gh)!
	assert remote_head(repo, ref)! == ''
	assert os.read_file(events)! == ''

	stage(repo, 'workflow release\n')!
	propose_staged(repo, 'master', '3.5.0', gh)!
	first := remote_head(repo, ref)!
	assert first != '' && first != base
	assert os.read_file(events)! == 'draft\nCI\n'

	git(repo, ['checkout', '--detach', base])!
	stage(repo, 'workflow release\n')!
	propose_staged(repo, 'master', '3.5.0', gh)!
	assert remote_head(repo, ref)! == first
	assert os.read_file(events)! == 'draft\nCI\n'

	stage(repo, 'refreshed workflow release\n')!
	propose_staged(repo, 'master', '3.5.0', gh)!
	second := remote_head(repo, ref)!
	assert second != first
	assert os.read_file(events)! == 'draft\nCI\nCI\n'

	os.rm(request)!
	git(repo, ['checkout', '--detach', base])!
	stage(repo, 'refreshed workflow release\n')!
	propose_staged(repo, 'master', '3.5.0', gh)!
	assert remote_head(repo, ref)! == second
	assert os.read_file(events)! == 'draft\nCI\nCI\ndraft\nCI\n'
}

fn self_test() ! {
	directory := os.join_path(os.temp_dir(), 'proposal fixture ' + rand.uuid_v4())
	os.mkdir(directory)!
	defer { os.rmdir_all(directory) or {} }
	test_generated_scope(directory)!
	remote := os.join_path(directory, 'remote.git')
	repo := os.join_path(directory, 'work')
	os.mkdir(repo)!
	git(directory, ['init', '--bare', remote])!
	git(repo, ['init', '--initial-branch=master'])!
	git(repo, ['config', 'user.name', 'Fixture'])!
	git(repo, ['config', 'user.email', 'fixture@example.invalid'])!
	git(repo, ['config', 'commit.gpgsign', 'false'])!
	stage(repo, 'old bindings\n')!
	git(repo, ['commit', '-m', 'base'])!
	git(repo, ['remote', 'add', 'origin', remote])!
	git(repo, ['push', 'origin', 'master'])!
	base := git(repo, ['rev-parse', 'HEAD'])!
	branch := 'automation/generated-update'
	ref := 'refs/heads/' + branch
	message := "Regenerate the project's bindings"
	assert !publish(repo, branch, message)!
	assert remote_head(repo, ref)! == ''

	stage(repo, 'new bindings\n')!
	assert publish(repo, branch, message)!
	first := remote_head(repo, ref)!
	assert first != '' && first != base
	assert git(repo, ['log', '-1', '--format=%s'])! == message
	// All branch switches and remote updates are confined to the fixture.
	git(repo, ['checkout', '--detach', base])!
	stage(repo, 'new bindings\n')!
	assert !publish(repo, branch, message)!
	assert git(repo, ['rev-parse', 'HEAD'])! == base
	assert remote_head(repo, ref)! == first
	stage(repo, 'changed bindings\n')!
	assert publish(repo, branch, message)!
	second := remote_head(repo, ref)!
	assert second != '' && second != first

	git(repo, ['checkout', '--detach', base])!
	os.write_file(os.join_path(repo, 'loader.v'), 'updated loader\n')!
	git(repo, ['add', '--', 'loader.v'])!
	git(repo, ['commit', '-m', 'base update'])!
	stage(repo, 'changed bindings\n')!
	assert publish(repo, branch, message)!
	third := remote_head(repo, ref)!
	assert third != second
	assert git(repo, ['show', 'HEAD:loader.v'])! == 'updated loader'

	stage(repo, 'racing bindings\n')!
	plan := plan_proposal(repo, branch)!
	assert plan.expected == third
	git(remote, ['update-ref', ref, base, third])!
	expect_rejected_lease(repo, plan, message)!
	assert remote_head(repo, ref)! == base

	stage(repo, 'racing creation\n')!
	new_branch := 'automation/new-branch'
	new_ref := 'refs/heads/' + new_branch
	first_plan := plan_proposal(repo, new_branch)!
	assert first_plan.needed && first_plan.expected == ''
	git(remote, ['update-ref', new_ref, base])!
	expect_rejected_lease(repo, first_plan, message)!
	assert remote_head(repo, new_ref)! == base

	output := os.join_path(directory, 'actions-output')
	write_output(output, true)!
	write_output(output, false)!
	assert os.read_file(output)! == 'pushed=true\npushed=false\n'
	test_proposal_workflow(repo, directory, base)!
	println('Publisher creation, no-op, update, lease, and draft fixtures passed.')
}

fn run_cli() ! {
	mut parser := flag.new_flag_parser(os.args[1..])
	parser.application('publish_generated_branch')
	parser.description('Publish a staged Git tree using a lease on the proposal branch.')
	test := parser.bool('self-test', 0, false, 'run against temporary local Git repositories')
	propose := parser.bool('propose', 0, false,
		'publish generated changes and ensure a draft exists')
	if parser.bool('help', `h`, false, 'show help') {
		println(parser.usage())
		return
	}
	args := parser.finalize()!
	if test && !propose && args.len == 0 {
		self_test()!
		return
	}
	if propose && !test && args.len == 0 {
		propose_workflow(os.getwd(), os.getenv('DEFAULT_BRANCH'))!
		return
	}
	if test || propose || args.len != 2 {
		return error('expected a proposal branch and a commit message. See --help.')
	}
	pushed := publish(os.getwd(), args[0], args[1])!
	write_output(os.getenv('GITHUB_OUTPUT'), pushed)!
}

run_cli() or {
	eprintln(err)
	exit(1)
}
