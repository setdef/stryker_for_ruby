# frozen_string_literal: true

require_relative "build_cop_script_run"
require_relative "scratch_clone"

# Helpers for the tests of .github/scripts/build-cop.sh, which run it as a
# subprocess in a clone of an origin on this computer, with the task that says
# what to do replaced by a file that says what it is told to, and gh by one
# that writes down what it was asked. Nothing reaches the network.
module BuildCopScriptCase
  include ScratchClone
  include BuildCopScriptRun

  WITH_DISPATCH = "name: CI\non:\n  push:\n    branches: [trunk]\n  workflow_dispatch:\n"
  WITHOUT_DISPATCH = "name: CI\non:\n  push:\n    branches: [trunk]\n"
  LIST_ONCE = { BUILD_COP_LIST_TRIES: "1", BUILD_COP_LIST_PAUSE: "0" }.freeze
  private_constant(:WITH_DISPATCH, :WITHOUT_DISPATCH, :LIST_ONCE)

  def setup
    super
    FileUtils.mkdir_p(File.join(@work, "tasks"))
    install_fake_gh
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

  # The file of reverts that the script gave the task.
  def reverts_seen
    File.read(File.join(@dir, "reverts.seen"))
  end

  # The file of commits that the script gave the task.
  def commits_seen
    File.read(File.join(@dir, "commits.seen"))
  end

  def gh_log
    path = File.join(@dir, "gh.log")
    File.exist?(path) ? File.read(path) : ""
  end

  # How long each sleep that the script asked for was to last, in seconds.
  def sleeps
    path = File.join(@dir, "sleep.log")
    File.exist?(path) ? File.readlines(path, chomp: true) : []
  end

  def origin_branches
    git(@dir, "--git-dir", @origin, "branch", "--list", "bisect/*")
  end

  # Runs the script as +cop+ does, with the Ruby in +source+ as the task, and
  # returns its output once it failed.
  def failing_cop_with_task(source, env = {})
    out, status = run_task(source, env)

    refute_predicate(status, :success?, out)
    out
  end

  private def run_script(commit, action, env)
    run_task(task_saying(commit, action), env)
  end
end
