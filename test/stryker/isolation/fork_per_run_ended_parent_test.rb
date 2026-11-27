# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "json"
require "stryker/config"
require "stryker/isolation"
require "tmpdir"

# What the fork adapter does when the parent has ended before it is given a
# run, with a stand-in for its process, so the test runs on every system.
class ForkPerRunEndedParentTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  # Says it is ready, and has ended by the time anything gives it a run: the
  # pipe that carries its runs has no reader.
  class EndedLaunch
    def call(_runner)
      _, commands = IO.pipe.tap { |input, _| input.close }
      results, output = IO.pipe
      output.puts(JSON.generate({ ready: true }))
      output.close
      child = Stryker::Isolation::Child.new(IsolationStandIns::FakeProcess::PID, IsolationStandIns::FakeProcess.new)
      Stryker::Isolation::ParentProcess.new(child, [commands, results], Dir.mktmpdir)
    end
  end
  private_constant(:EndedLaunch)

  def test_the_adapter_raises_its_error_when_the_parent_has_ended_before_it_is_given_a_run
    isolation = Stryker::Isolation::ForkPerRun.new("/cache", "/project", EndedLaunch.new)
    isolation.start(Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest"))
    error = assert_raises(Stryker::Isolation::Error) { isolation.run_all([sample_run(1)]) { nil } }

    assert_includes(error.message, "The fork parent ended before it took a run.")
  ensure
    isolation&.stop
  end
end
