# frozen_string_literal: true

require_relative "scratch_clone"

# How the tests of .github/scripts/build-cop.sh run it: as a subprocess in the
# clone, with the task replaced by one that says what it is told to, gh
# replaced by one that writes down what it was asked, and a push that only the
# App's token reaches the origin with. Nothing reaches the network.
module BuildCopScriptRun
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

  # What a run on GitHub has, which the script falls back on when the
  # environment names none.
  GITHUB = "https://github.com"
  REPOSITORY = "setdef/stryker_for_ruby"
  private_constant(:GITHUB, :REPOSITORY)

  # sleep without the wait, which writes down how long it was asked for.
  FAKE_SLEEP = <<~SH
    #!/bin/sh
    echo "$@" >>"DIR/sleep.log"
  SH
  private_constant(:FAKE_SLEEP)

  # Puts the fake gh and the fake sleep first on the PATH of the script's runs.
  def install_fake_gh
    FileUtils.mkdir_p(File.join(@dir, "bin"))
    File.write(File.join(@dir, "bin", "gh"), FAKE_GH.gsub("DIR", @dir), perm: 0o755)
    File.write(File.join(@dir, "bin", "sleep"), FAKE_SLEEP.gsub("DIR", @dir), perm: 0o755)
  end

  private def run_task(source, env)
    File.write(File.join(@work, "tasks", "build_cop.rb"), source)
    path = [File.join(@dir, "bin"), ENV.fetch("PATH", nil)].join(File::PATH_SEPARATOR)
    environment = variables(GIT_ENV, app_token, { PATH: path }, env)
    Open3.capture2e(environment.merge(pushes_by_token(environment)), "bash", SCRIPT, chdir: @work)
  end

  # The task's reason is the repository that the script gave it, and it keeps
  # the files of commits and reverts that the script gave it in commits.seen
  # and reverts.seen.
  private def task_saying(commit, action)
    fields = { action:, commit:, run: 1 }.map { |name, value| "#{name}=#{value}" }
    <<~RUBY
      class BuildCop
        def self.main(commits, reverts)
          File.write(#{File.join(@dir, 'commits.seen').inspect}, File.read(commits))
          File.write(#{File.join(@dir, 'reverts.seen').inspect}, File.read(reverts))
          puts(#{fields.inspect}, "reason=\#{ENV['GITHUB_REPOSITORY']}")
        end
      end
    RUBY
  end

  # The server, repository and token that the script pushes with.
  private def app_token
    { GITHUB_SERVER_URL: "https://github.example", GITHUB_REPOSITORY: REPOSITORY, BUILD_COP_PUSH_TOKEN: "app-token" }
  end

  # The run's own credentials may not push a workflow file, so a push to the
  # remote the clone knows as origin goes nowhere, and only the App's token, in
  # the URL that the script builds from +environment+, reaches the origin.
  private def pushes_by_token(environment)
    server = environment["GITHUB_SERVER_URL"] || GITHUB
    repository = environment["GITHUB_REPOSITORY"] || REPOSITORY
    url = "https://x-access-token:#{environment['BUILD_COP_PUSH_TOKEN']}@#{server.delete_prefix('https://')}/#{repository}"
    settings = [["url.#{@origin}.insteadOf", url], ["remote.origin.pushurl", File.join(@dir, "nowhere.git")]]
    config = settings.each_with_index.flat_map do |(key, value), index|
      [["GIT_CONFIG_KEY_#{index}", key], ["GIT_CONFIG_VALUE_#{index}", value]]
    end
    variables({ GIT_CONFIG_COUNT: settings.size.to_s }, config.to_h)
  end
end
