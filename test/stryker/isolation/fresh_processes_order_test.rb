# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/config"
require "stryker/isolation/fresh_processes"
require "stryker/testing"

# When a fresh process's result arrives, and when its slot frees: as soon as
# the process ends, while a run that started before it, and whose time ends
# before its own, goes on (#87). Real processes, of the isolation contract's
# sample project, with a test that naps added to it, so that a run is still
# testing when the hanging run's deadline is the soonest.
class FreshProcessesOrderTest < Minitest::Test
  parallelize_me!

  NAPS = <<~RUBY
    require "test_helper"

    class IsolationSampleTest < Minitest::Test
      def test_naps
        sleep(0.5)
      end
    end
  RUBY
  private_constant(:NAPS)

  def test_a_run_that_ends_while_an_earlier_run_goes_on_lands_and_frees_its_slot_at_once
    ids = Stryker::Testing::IsolationContract::SampleProject.open(static: true) do |sample|
      Stryker::Testing::IsolationContract::SampleProject.write(File.join(sample.root, "test", "naps_test.rb"), NAPS)
      # The hanging run's time ends before the others', and each other run
      # ends while it hangs.
      first_two(sample, [sample.run(10, :hangs, timeout_ms: 20_000), sample.run(11, :naps), sample.run(12, :naps)])
    end

    assert_equal([11, 12], ids)
  end

  # The mutant IDs of the first two results, two runs at a time, after which
  # the adapter stops, and ends the run still going.
  private def first_two(sample, runs)
    adapter = Stryker::Isolation::FreshProcesses.new(sample.cache, sample.root)
    adapter.start(Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", concurrency: 2))
    ids = []
    adapter.run_all(runs) { |result| raise(StopIteration) if (ids << result.mutant.id).size == 2 }
  rescue StopIteration
    ids
  ensure
    adapter&.stop
  end
end
