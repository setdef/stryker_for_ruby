# frozen_string_literal: true

require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative("../test_helper")

# Checks that a signal that reaches a real process, while the pipeline runs,
# ends it with 128 plus the signal's number. The process signals itself, so
# the test needs no second process to deliver the signal.
class CLISignalTest < Minitest::Test
  LIB = File.expand_path("../../lib", __dir__)
  SCRIPT = <<~RUBY
    require "stryker/cli"
    pipeline = Object.new
    pipeline.define_singleton_method(:call) do |*, **|
      Process.kill(ARGV.first, Process.pid)
      sleep
    end
    exit(Stryker::CLI.call(["run"], pipeline:, root: Dir.pwd))
  RUBY
  private_constant(:LIB, :SCRIPT)

  def test_terminate_ends_the_run_as_a_shell_reports_it
    assert_equal([143, "Stopped by TERM.\n"], signalled("TERM"))
  end

  def test_interrupt_ends_the_run_as_a_shell_reports_ctrl_c
    assert_equal([130, "Stopped by INT.\n"], signalled("INT"))
  end

  private def signalled(name)
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "test"))
      _out, err, status = Open3.capture3(RbConfig.ruby, "-I", LIB, "-e", SCRIPT, name, chdir: root)
      [status.exitstatus, err]
    end
  end
end
