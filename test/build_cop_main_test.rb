# frozen_string_literal: true

require "stringio"
require "tmpdir"
require_relative "support/build_cop_case"

# The command that .github/scripts/build-cop.sh runs: it prints the cop's step
# as lines for GITHUB_OUTPUT, and ends the run with a failure of GitHub's API
# as an error annotation.
class BuildCopMainTest < Minitest::Test
  include BuildCopCase

  def test_prints_the_step_as_lines_for_github_output
    out = StringIO.new
    serve(ci_run("a", 1, "success"), ci_run("f", 2, "success")) { run_main({}, out:) }

    assert_equal(
      "action=none\ncommit=\nrun=\nreason=no run on trunk since #{commit('f')}'s green one is red\n",
      out.string
    )
  end

  # E's run is red and F reverts D, which E's run covers: the file of reverts
  # says so, as the script writes it.
  def test_reads_the_reverts_among_the_commits_from_its_file
    out = StringIO.new
    serve(ci_run("a", 1, "success"), ci_run("e", 2, "failure")) do
      run_main({}, out:, reverts: "#{commit('f')} #{commit('d')}\n")
    end

    assert_match(/\Aaction=none\n.*settled/m, out.string)
  end

  # No route answers 404 to every request.
  def test_ends_the_run_with_the_message_of_a_failure_of_the_api
    assert_match(/\AGitHub's API answered 404/, failing_main({}))
  end

  def test_the_message_is_an_error_annotation_inside_github_actions
    assert_match(/\A::error::GitHub's API answered 404/, failing_main(GITHUB_ACTIONS: "true"))
  end

  private def failing_main(extra)
    _out, err = capture_io do
      github_serving({}) { assert_raises(SystemExit) { run_main(extra) } }
    end
    err
  end

  private def run_main(extra, out: StringIO.new, reverts: "")
    env = { GITHUB_REPOSITORY: "setdef/stryker_for_ruby", GH_TOKEN: "secret", GITHUB_API_URL: FakeGitHub::API }
    Dir.mktmpdir do |dir|
      path = File.join(dir, "commits.txt")
      File.write(path, "#{COMMITS.reverse.join("\n")}\n\n")
      reverts_path = File.join(dir, "reverts.txt")
      File.write(reverts_path, reverts)
      BuildCop.main(path, reverts_path, env: env.merge(extra).transform_keys(&:to_s), out:, now: NOW)
    end
  end
end
