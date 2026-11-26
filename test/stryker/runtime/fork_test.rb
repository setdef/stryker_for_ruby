# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks what a forked child does with the collector that its parent started,
# in processes of their own. A forked child can't use its parent's Ractors.
class ForkTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  # Makes a hit in a Ractor while the parent loads, and forks a dry run's
  # child that makes another, in a test.
  DRY_RUN = <<~RUBY
    require "stryker/runtime"
    $stdout.sync = true
    recorder = Stryker::Runtime::RECORDER
    Ractor.new { Stryker::Active.hit(1) }.value
    recorder.drain
    pid = fork do
      Stryker::Runtime.start_dry_run
      recorder.test_started(:first)
      Ractor.new { Stryker::Active.hit(2) }.value
      recorder.test_finished(:passed)
      $stdout.puts([recorder.static.to_a, recorder.tests[:first].to_a].inspect)
      exit!(0)
    end
    Process.wait(pid)
  RUBY

  # Forks a mutant run's child, which runs a test with a hit.
  MUTANT_RUN = <<~RUBY
    require "stryker/runtime"
    $stdout.sync = true
    recorder = Stryker::Runtime::RECORDER
    pid = fork do
      Stryker::Runtime.activate_mutant(9)
      recorder.test_started(:first)
      Stryker::Active.hit(3)
      recorder.test_finished(:passed)
      $stdout.puts([Stryker::Active.id, recorder.static.to_a, recorder.tests[:first].to_a].inspect)
      exit!(0)
    end
    Process.wait(pid)
  RUBY
  private_constant(:DRY_RUN, :MUTANT_RUN)

  def setup
    skip("Windows has no fork.") unless Process.respond_to?(:fork)
  end

  # The hit that a Ractor made while the parent loaded is in the static
  # bucket that the child inherits, and the child's own collector takes the
  # hit that a Ractor makes during its test.
  def test_a_forked_dry_run_starts_a_collector_of_its_own
    assert_equal("[[1], [2]]\n", run_program(DRY_RUN).first)
  end

  # The child records no hit and drains nothing, so the dead collector that
  # it inherited is never asked.
  def test_a_forked_mutant_run_ignores_the_collector_its_parent_started
    assert_equal("[9, [], []]\n", run_program(MUTANT_RUN).first)
  end
end
