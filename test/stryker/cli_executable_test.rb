# frozen_string_literal: true

require "open3"
require "rbconfig"
require_relative("../test_helper")

# Checks the executable as a user runs it: a fresh process, real streams, and
# a real exit status.
class CLIExecutableTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  EXECUTABLE = File.join(ROOT, "exe", "stryker")
  # Prism and refract cost most of a run's start-up, and only `stryker run`
  # uses them. The probe prints each of them that the other commands load.
  NO_PARSER_PROBE = <<~RUBY
    require "stringio"
    require "stryker/cli"
    [["--version"], ["help"], ["help", "run"]].each { |argv| Stryker::CLI.call(argv, stdout: StringIO.new) }
    puts($LOADED_FEATURES.grep(%r{/(?:prism|refract)(?:/|\\.rb\\z)}))
  RUBY
  private_constant(:ROOT, :EXECUTABLE, :NO_PARSER_PROBE)

  def test_version_goes_to_standard_output
    out, err, status = stryker("--version")

    assert_equal(["#{Stryker::VERSION}\n", "", 0], [out, err, status.exitstatus])
  end

  def test_an_unknown_command_goes_to_standard_error_with_status_two
    out, err, status = stryker("frobnicate")

    assert_equal(["", 2], [out, status.exitstatus])
    assert_includes(err, %(Unknown command "frobnicate"))
  end

  def test_the_version_and_the_help_load_neither_prism_nor_refract
    out, _err, status = Open3.capture3(RbConfig.ruby, "-I", File.join(ROOT, "lib"), "-e", NO_PARSER_PROBE)

    assert_equal([0, ""], [status.exitstatus, out])
  end

  def test_the_gemspec_ships_the_executable
    spec = Gem::Specification.load(File.expand_path("../../stryker_for_ruby.gemspec", __dir__))

    assert_equal([["stryker"], true], [spec.executables, spec.files.include?("exe/stryker")])
  end

  def test_a_closed_standard_output_ends_the_command_quietly_as_sigpipe_ends_a_program
    assert_equal([141, ""], closed("--version", stream: :out))
  end

  def test_a_closed_standard_error_ends_the_command_quietly_as_sigpipe_ends_a_program
    assert_equal([141, ""], closed("frobnicate", stream: :err))
  end

  # Runs the command with one stream a pipe whose reader has gone, and the
  # other a pipe that the test reads, and gives the status and what the other
  # stream held.
  private def closed(*argv, stream:)
    reader, writer = IO.pipe
    gone_reader, gone_writer = IO.pipe
    gone_reader.close
    streams = (stream == :out) ? { out: gone_writer, err: writer } : { out: writer, err: gone_writer }
    pid = Process.spawn(RbConfig.ruby, "-I", File.join(ROOT, "lib"), EXECUTABLE, *argv, **streams)
    [writer, gone_writer].each(&:close)
    status = Process.wait2(pid).last
    [status.exitstatus, reader.read]
  ensure
    reader&.close
  end

  private def stryker(*argv)
    Open3.capture3(RbConfig.ruby, "-I", File.join(ROOT, "lib"), EXECUTABLE, *argv)
  end
end
