# frozen_string_literal: true

require_relative("support/load_probes")
require_relative("test_helper")

# Which probes count as failed, with a stand-in for Process that ends each
# probe the way a test says, on every system.
class LoadProbesTest < Minitest::Test
  # Starts nothing, and ends each probe with the status that was set for it.
  class EndingProcess
    Status = Struct.new(:success?)
    private_constant(:Status)

    def initialize(statuses)
      @statuses = statuses
      @started = []
    end

    def spawn(*_command, **_options)
      @started << @statuses[@started.size]
      @started.size
    end

    def wait2(pid)
      [pid, Status.new(@started[pid - 1])]
    end
  end

  def failed(*statuses)
    paths = statuses.each_index.map { |index| "probe-#{index}" }
    LoadProbes.new("/root", "script", EndingProcess.new(statuses)).failed(paths)
  end

  def test_a_probe_that_exits_with_success_has_not_failed
    assert_empty(failed(true))
  end

  def test_a_probe_that_exits_without_success_has_failed
    assert_equal(["probe-1"], failed(true, false))
  end

  def test_a_probe_that_a_signal_ended_has_failed
    assert_equal(["probe-0"], failed(nil, true))
  end
end
