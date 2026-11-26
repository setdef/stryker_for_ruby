# frozen_string_literal: true

require_relative "scratch_clone"

# Helpers for the tests of .github/scripts/build-cop.sh, which run it as a
# subprocess in a clone of an origin on this computer, with the task that says
# what to do replaced by a file that says what it is told to, and gh by one
# that writes down what it was asked. Nothing reaches the network.
module BuildCopScriptCase
  include ScratchClone

  SCRIPT = File.expand_path("../../.github/scripts/build-cop.sh", __dir__)
  private_constant(:SCRIPT)

  # gh as the script asks it: every call written down; a dispatch or a rerun
  # refused when the file gh.fail_dispatch or gh.fail_rerun is there; and the
  # runs it lists are those in gh.live (the ID of the first run that is not
  # cancelled) and gh.any (how many runs there are at all), as the script's two
  # queries ask for.
  FAKE_GH = <<~SH
    #!/bin/sh
    echo "$@" >>"DIR/gh.log"
    case "$*" in
    *"workflow run"*) [ -f "DIR/gh.fail_dispatch" ] && exit 1 ;;
    *"run rerun"*) [ -f "DIR/gh.fail_rerun" ] && { echo "run cannot be rerun" >&2; exit 1; } ;;
    *"run list"*)
      case "$*" in
      *length*) cat "DIR/gh.any" 2>/dev/null ;;
      *) cat "DIR/gh.live" 2>/dev/null ;;
      esac
      ;;
    esac
    exit 0
  SH
  private_constant(:FAKE_GH)

  WITH_DISPATCH = "name: CI\non:\n  push:\n    branches: [trunk]\n  workflow_dispatch:\n"
  WITHOUT_DISPATCH = "name: CI\non:\n  push:\n    branches: [trunk]\n"
  TOKEN_URL = "https://x-access-token:app-token@github.example/setdef/stryker_for_ruby"
  LIST_ONCE = { BUILD_COP_LIST_TRIES: "1", BUILD_COP_LIST_PAUSE: "0" }.freeze
  private_constant(:WITH_DISPATCH, :WITHOUT_DISPATCH, :TOKEN_URL, :LIST_ONCE)

  def setup
    super
    FileUtils.mkdir_p(File.join(@work, "tasks"))
    FileUtils.mkdir_p(File.join(@dir, "bin"))
    File.write(File.join(@dir, "bin", "gh"), FAKE_GH.gsub("DIR", @dir), perm: 0o755)
  end

  # Runs the script when the task says +action+ about +commit+, and returns its
  # output once it ended well.
  def cop(commit, action, env = {})
    out, status = run_script(commit, action, env)

    assert_predicate(status, :success?, out)
    out
  end

  # Runs the script as +cop+ does, and returns its output once it failed.
  def failing_cop(commit, action, env = {})
    out, status = run_script(commit, action, env)

    refute_predicate(status, :success?, out)
    out
  end

  # Runs the script for a commit to bisect, which waits no longer than once for
  # GitHub to list the run it started.
  def cop_bisecting(commit, env = {})
    cop(commit, "bisect", LIST_ONCE.merge(env))
  end

  # Runs the script as +cop_bisecting+ does, and returns its output once it
  # failed.
  def failing_bisect(commit, env = {})
    failing_cop(commit, "bisect", LIST_ONCE.merge(env))
  end

  # A commit of trunk, pushed, whose ci.yml is +workflow+.
  def bisect_commit(workflow)
    pushed_commit("feat: to bisect", ".github/workflows/ci.yml", workflow)
  end

  # A commit of trunk, pushed, that adds a file of its own.
  def pushed_commit(subject, path = "bad.txt", text = "bad\n")
    bad = commit(subject, path, text)
    git(@work, "push", "--quiet", "origin", "trunk")
    bad
  end

  def gh_log
    path = File.join(@dir, "gh.log")
    File.exist?(path) ? File.read(path) : ""
  end

  def origin_branches
    git(@dir, "--git-dir", @origin, "branch", "--list", "bisect/*")
  end

  private def run_script(commit, action, env)
    File.write(File.join(@work, "tasks", "build_cop.rb"), task_saying(commit, action))
    path = [File.join(@dir, "bin"), ENV.fetch("PATH", nil)].join(File::PATH_SEPARATOR)
    Open3.capture2e(variables(GIT_ENV, pushes_by_token, { PATH: path }, env), "bash", SCRIPT, chdir: @work)
  end

  # The task's reason is the repository that the script gave it.
  private def task_saying(commit, action)
    fields = { action:, commit:, run: 1 }.map { |name, value| "#{name}=#{value}" }
    <<~RUBY
      class BuildCop
        def self.main(_path) = puts(#{fields.inspect}, "reason=\#{ENV['GITHUB_REPOSITORY']}")
      end
    RUBY
  end

  # The run's own credentials may not push a workflow file, so a push to the
  # remote the clone knows as origin goes nowhere, and only the App's token, in
  # the URL the script builds, reaches the origin.
  private def pushes_by_token
    settings = [["url.#{@origin}.insteadOf", TOKEN_URL], ["remote.origin.pushurl", File.join(@dir, "nowhere.git")]]
    config = settings.each_with_index.flat_map do |(key, value), index|
      [["GIT_CONFIG_KEY_#{index}", key], ["GIT_CONFIG_VALUE_#{index}", value]]
    end
    {
      GITHUB_SERVER_URL: "https://github.example",
      GITHUB_REPOSITORY: "setdef/stryker_for_ruby",
      BUILD_COP_PUSH_TOKEN: "app-token",
      GIT_CONFIG_COUNT: settings.size.to_s,
    }.merge(config.to_h)
  end
end
