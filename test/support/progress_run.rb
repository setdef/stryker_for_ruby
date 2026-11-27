# frozen_string_literal: true

require_relative("../test_helper")
require "stringio"
require "stryker/dry_run_result"
require "stryker/events"
require "stryker/mutant"
require "stryker/mutant_result"
require "stryker/mutant_run"
require "stryker/reporters/progress"
require "stryker/test"
require "stryker/test_result"

# The events of a small run, for the tests of the progress reporter. The dry
# run has a slow test that takes 30 ms and a fast one that takes 10 ms, and
# spends 5 ms besides, so the plan's three runs weigh 30, 15 (a static run of
# the fast test, which adds the 5 ms), and 10: 55 in all. A fourth mutant has
# no test, so the plan leaves it out of the work.
module ProgressRun
  # A clock that the test sets, so that no test waits.
  class Clock
    def initialize
      @seconds = 0.0
    end

    def call
      @seconds
    end

    def advance(seconds)
      @seconds += seconds
    end
  end

  def self.test(id)
    Stryker::Test.new(id:, name: id, file: nil, location: nil)
  end

  def self.mutant(id)
    Stryker::Mutant.new(
      id:, file: "lib/a.rb", mutator_name: "EqualityOperator", start_offset: 0, end_offset: 1, replacement: "-"
    )
  end

  def self.dry_run(durations = [["slow", 30.0], ["fast", 10.0]], total: 45.0)
    results = durations.map do |id, duration_ms|
      Stryker::TestResult.new(test: test(id), status: "passed", failure_message: nil, duration_ms:)
    end
    result = Stryker::DryRunResult.new(
      results:, buckets: {}, static_bucket: [], files_loaded_in_tests: [], duration_ms: total
    )
    Stryker::Events::DryRunCompleted.new(result:)
  end

  def self.run(id, test_id, static: false)
    Stryker::MutantRun.new(mutant: mutant(id), static:, test_ids: [test_id], covered_by: [test_id], timeout_ms: 1500)
  end

  def self.plan(runs = [run(1, "slow"), run(2, "fast", static: true), run(3, "fast")])
    Stryker::Events::PlanReady.new(runs:, unrun: [])
  end

  def self.tested(id, status)
    Stryker::Events::MutantTested.new(result: Stryker::MutantResult.unrun(mutant(id), status))
  end

  def self.completed
    Stryker::Events::RunCompleted.new(results: [])
  end

  # What a test of the reporter does: builds it on a stand-in stream with the
  # clock above, and plays events to it.
  module Hearing
    def build(terminal:, color: false)
      @clock = Clock.new
      @io = StringIO.new
      ink = Stryker::Reporters::Ink.new(enabled: color)
      display = if terminal
        Stryker::Reporters::ProgressAnimation.new(@io, 200, ink)
      else
        Stryker::Reporters::ProgressLog.new(@io, ink)
      end
      @reporter = Stryker::Reporters::Progress.new(display:, clock: @clock)
    end

    def hear(*events)
      events.each { |event| @reporter.call(event) }
    end

    def start
      hear(ProgressRun.dry_run, ProgressRun.plan)
    end
  end
end
