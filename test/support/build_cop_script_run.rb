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

  TOKEN_URL = "https://x-access-token:app-token@github.example/setdef/stryker_for_ruby"
  private_constant(:TOKEN_URL)

  # Puts the fake gh first on the PATH of the script's runs.
  def install_fake_gh
    FileUtils.mkdir_p(File.join(@dir, "bin"))
    File.write(File.join(@dir, "bin", "gh"), FAKE_GH.gsub("DIR", @dir), perm: 0o755)
  end

  private def run_task(source, env)
    File.write(File.join(@work, "tasks", "build_cop.rb"), source)
    path = [File.join(@dir, "bin"), ENV.fetch("PATH", nil)].join(File::PATH_SEPARATOR)
    Open3.capture2e(variables(GIT_ENV, pushes_by_token, { PATH: path }, env), "bash", SCRIPT, chdir: @work)
  end

  # The task's reason is the repository that the script gave it, and it keeps
  # the file of reverts that the script gave it in reverts.seen.
  private def task_saying(commit, action)
    fields = { action:, commit:, run: 1 }.map { |name, value| "#{name}=#{value}" }
    <<~RUBY
      class BuildCop
        def self.main(_path, reverts)
          File.write(#{File.join(@dir, 'reverts.seen').inspect}, File.read(reverts))
          puts(#{fields.inspect}, "reason=\#{ENV['GITHUB_REPOSITORY']}")
        end
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
