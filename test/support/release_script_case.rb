# frozen_string_literal: true

require_relative "loopback_github"
require_relative "release_repository"

# Helpers for the tests of .github/scripts/release.sh, which run it as a
# subprocess in a clone of an origin on this computer, with the repository's
# own tasks, gh replaced by one that writes down what it was asked, and the
# GitHub API replaced by LoopbackGitHub. Nothing reaches the network.
module ReleaseScriptCase
  include ReleaseRepository

  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, ".github/scripts/release.sh")
  TASKS = File.join(ROOT, "tasks")
  REPOSITORY = "setdef/stryker_for_ruby"
  TOKEN_URL = "https://x-access-token:push-token@github.example/#{REPOSITORY}".freeze
  private_constant(:ROOT, :SCRIPT, :TASKS, :REPOSITORY, :TOKEN_URL)

  # gh as the script asks it: every call written down; a release that exists
  # when the file gh.exists is there; a creation refused when gh.fail_create is.
  FAKE_GH = <<~SH
    #!/bin/sh
    echo "$@" >>"DIR/gh.log"
    case "$*" in
    "release view"*) [ -f "DIR/gh.exists" ] || exit 1 ;;
    "release create"*) [ -f "DIR/gh.fail_create" ] && exit 1 ;;
    esac
    exit 0
  SH
  private_constant(:FAKE_GH)

  def setup
    super
    FileUtils.mkdir_p(File.join(@dir, "bin"))
    File.write(File.join(@dir, "bin", "gh"), FAKE_GH.gsub("DIR", @dir), perm: 0o755)
    # The files the gemspec lists, which `gem build` refuses to build without.
    FileUtils.cp(File.join(ROOT, "stryker_for_ruby.gemspec"), @work)
    FileUtils.cp_r(File.join(ROOT, "exe"), @work)
    @api = nil
  end

  def teardown
    @api&.close
    super
  end

  # Runs +step+ of the script, and returns its output once it ended well.
  def script(step, env = {})
    out, status = run_script(step, env)

    assert_predicate(status, :success?, out)
    out
  end

  # Runs +step+ as +script+ does, and returns its output once it failed.
  def failing_script(step, env = {})
    out, status = run_script(step, env)

    refute_predicate(status, :success?, out)
    out
  end

  # Serves a run of ci.yml that passed every job for +sha+, on trunk.
  def serve_green_run(sha)
    job = { name: "Gate", status: "completed", conclusion: "success", run_attempt: 1 }
    base = "/repos/#{REPOSITORY}/actions"
    @api = LoopbackGitHub.new(
      "#{base}/workflows/ci.yml/runs" => { total_count: 1, workflow_runs: [green_run(sha)] },
      "#{base}/runs/7/jobs" => { total_count: 1, jobs: [job] }
    )
  end

  # What the script wrote to GITHUB_OUTPUT, as a Hash.
  def outputs
    path = File.join(@dir, "output.txt")
    return {} unless File.exist?(path)

    File.foreach(path, chomp: true).to_h { |line| line.split("=", 2) }
  end

  def gh_log
    path = File.join(@dir, "gh.log")
    File.exist?(path) ? File.read(path) : ""
  end

  # Pushes the clone's trunk to the origin, as a commit made elsewhere is.
  def push_trunk
    git(@work, "push", "--quiet", "origin", "trunk")
  end

  private def green_run(sha)
    {
      id: 7,
      head_sha: sha,
      head_branch: "trunk",
      event: "push",
      run_attempt: 1,
      status: "completed",
      conclusion: "success",
    }
  end

  private def run_script(step, env)
    environment = variables(GIT_ENV, pushes_by_token, script_environment, env)
    Open3.capture2e(environment, "bash", SCRIPT, step, chdir: @work)
  end

  private def script_environment
    path = [File.join(@dir, "bin"), ENV.fetch("PATH", nil)].join(File::PATH_SEPARATOR)
    fixed = {
      PATH: path,
      RELEASE_TASKS: TASKS,
      GITHUB_OUTPUT: File.join(@dir, "output.txt"),
      GITHUB_REPOSITORY: REPOSITORY,
      GH_TOKEN: "read-token",
      GITHUB_REF: "refs/heads/trunk",
    }
    @api ? fixed.merge(GITHUB_API_URL: @api.url) : fixed
  end

  # The run's own credentials may not push to trunk where a workflow could,
  # so a push to the remote the clone knows as origin goes nowhere, and only
  # the token in the URL the script builds reaches the origin.
  private def pushes_by_token
    settings = [["url.#{@origin}.insteadOf", TOKEN_URL], ["remote.origin.pushurl", File.join(@dir, "nowhere.git")]]
    config = settings.each_with_index.flat_map do |(key, value), index|
      [["GIT_CONFIG_KEY_#{index}", key], ["GIT_CONFIG_VALUE_#{index}", value]]
    end
    {
      GITHUB_SERVER_URL: "https://github.example",
      RELEASE_PUSH_TOKEN: "push-token",
      GIT_CONFIG_COUNT: settings.size.to_s,
    }.merge(config.to_h)
  end
end
