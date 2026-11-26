# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "open3"
require "stryker/instrumenter/parse_worker_child"
require "stryker/instrumenter/parse_worker_stderr"

# Checks how the operating system's side of a parse worker ends its process.
class ParseWorkerChildTest < Minitest::Test
  def teardown
    @child&.stop
  end

  def child
    @child ||= begin
      input, output, waiter = Open3.popen2(RbConfig.ruby, "-e", "sleep")
      errors = Stryker::Instrumenter::ParseWorkerStderr.open
      Stryker::Instrumenter::ParseWorkerChild.new(input, output, waiter, errors)
    end
  end

  def test_halting_ends_the_process_and_leaves_the_file_of_standard_error
    child.halt

    assert_equal([false, ""], [child.running?, child.last_lines])
  end

  def test_the_signal_may_find_the_process_gone
    Process.stub(:kill, -> (*) { raise(Errno::ESRCH) }) { child.__send__(:kill) }

    assert_predicate(child, :running?)
  end
end
