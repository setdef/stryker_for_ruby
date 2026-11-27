# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/command"
require "stryker/isolation/ending"
require "stryker/isolation/finisher"
require "stryker/runtime"

# The small parts that the isolation adapters share: the finisher, a
# process's ending, and the command and environment of a project process.
# timer_test.rb checks the timer.
class SmallPartsTest < Minitest::Test
  include IsolationStandIns

  Status = Data.define(:exitstatus, :termsig)
  private_constant(:Status)

  # A report whose conclude runs the block and returns +code+.
  class Report
    def initialize(code)
      @code = code
    end

    def conclude
      yield
      @code
    end
  end
  private_constant(:Report)

  def ended(exitstatus, termsig = nil, timed_out: false)
    Stryker::Isolation::Ending.of(Status.new(exitstatus:, termsig:), timed_out:, duration_ms: 1.5)
  end

  def test_the_finisher_ends_the_process_with_the_status_the_report_gives
    process = FakeProcess.new
    ran = false
    Stryker::Isolation::Finisher.new(process).call(Report.new(0)) { ran = true }

    assert_equal([true, [[:exit!, 0]]], [ran, process.calls])
  end

  def test_the_finisher_ends_the_process_with_status_one_when_the_report_lets_an_exception_through
    process = FakeProcess.new

    assert_raises(Interrupt) { Stryker::Isolation::Finisher.new(process).call(Report.new(0)) { raise(Interrupt) } }
    assert_equal([[:exit!, 1]], process.calls)
  end

  def test_an_ending_reads_an_exit_status
    ending = ended(3)

    assert_equal(
      [3, nil, "exited with status 3", false],
      [ending.exit_status, ending.signal, ending.description, ending.clean?]
    )
  end

  def test_an_ending_reads_a_signal
    ending = ended(nil, 9, timed_out: true)

    assert_equal(
      [nil, "KILL", "was ended by signal KILL", true],
      [ending.exit_status, ending.signal, ending.description, ending.timed_out]
    )
  end

  def test_an_ending_with_status_zero_is_clean_and_crosses_a_pipe
    ending = ended(0)

    assert_predicate(ending, :clean?)
    assert_equal(ending, Stryker::Isolation::Ending.from_json(ending.to_json))
  end

  def test_the_command_starts_the_entry_point_with_the_arguments_after_its_options
    argv = Stryker::Isolation::Command.for("fresh", "/cache", "minitest", "0.run", "0.results")
    entry = File.expand_path("../../../lib/stryker/isolation/project_process.rb", __dir__)

    assert_equal([RbConfig.ruby, "-r", entry, "-e", "Stryker::Isolation::ProjectProcess.main", "--"], argv.first(6))
    assert_equal(%w[fresh /cache minitest 0.run 0.results], argv.drop(6))
    assert_path_exists(Stryker::Isolation::Command::ENTRY)
  end

  def test_the_environment_names_the_active_mutant_or_unsets_the_variable
    assert_equal(Stryker::Runtime::VARIABLE, Stryker::Isolation::Command::ACTIVE_MUTANT)
    assert_equal({ Stryker::Runtime::VARIABLE => "7" }, Stryker::Isolation::Command.environment(7))
    assert_equal({ Stryker::Runtime::VARIABLE => nil }, Stryker::Isolation::Command.environment)
  end
end
