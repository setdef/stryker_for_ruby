# frozen_string_literal: true

require "open3"
require "rbconfig"
require_relative("../test_helper")

# Checks the executable as a user runs it: a fresh process, real streams, and
# a real exit status.
class CLIExecutableTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  EXECUTABLE = File.join(ROOT, "exe", "stryker")
  private_constant(:ROOT, :EXECUTABLE)

  def test_version_goes_to_standard_output
    out, err, status = stryker("--version")

    assert_equal(["#{Stryker::VERSION}\n", "", 0], [out, err, status.exitstatus])
  end

  def test_an_unknown_command_goes_to_standard_error_with_status_two
    out, err, status = stryker("frobnicate")

    assert_equal(["", 2], [out, status.exitstatus])
    assert_includes(err, %(Unknown command "frobnicate"))
  end

  def test_the_gemspec_ships_the_executable
    spec = Gem::Specification.load(File.expand_path("../../stryker_for_ruby.gemspec", __dir__))

    assert_equal([["stryker"], true], [spec.executables, spec.files.include?("exe/stryker")])
  end

  private def stryker(*argv)
    Open3.capture3(RbConfig.ruby, "-I", File.join(ROOT, "lib"), EXECUTABLE, *argv)
  end
end
