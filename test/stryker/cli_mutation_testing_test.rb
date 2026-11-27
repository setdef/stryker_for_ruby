# frozen_string_literal: true

require_relative("../test_helper")
require "stringio"
require "stryker/cli/color"
require "stryker/cli/mutation_testing"
require "stryker/cli/streams"
require "stryker/config"
require "stryker/events/run_completed"
require "tmpdir"

# Checks how the command builds a run for the system it is on: which
# isolation adapters and reporters it hands the pipeline, and what it
# refuses before any file is read.
class CLIMutationTestingTest < Minitest::Test
  # Stands in for Stryker::Pipeline: records what it was built with, and
  # gives a score.
  class Pipeline
    class << self
      attr_reader :built
    end

    def initialize(root, isolations, reporters)
      self.class.instance_variable_set(:@built, [root, isolations, reporters])
    end

    def call(_config)
      75.0
    end
  end

  # Stands in for a terminal.
  class Terminal < StringIO
    def tty?
      true
    end
  end

  def config(**)
    Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", **)
  end

  def run_with(forks: true, stdout: StringIO.new, **)
    testing = Stryker::CLI::MutationTesting.new("/project", forks:, pipeline: Pipeline)
    testing.call(config(**), Stryker::CLI::Streams.new(stdout, StringIO.new), Stryker::CLI::Color.new(false))
  end

  def test_the_pipeline_runs_in_the_project_and_its_score_is_the_runs
    assert_equal([75.0, "/project"], [run_with(reporters: []), Pipeline.built.first])
  end

  def test_where_the_system_forks_the_runtime_mutants_fork_and_the_static_mutants_get_fresh_processes
    run_with(reporters: [])
    isolations = Dir.mktmpdir { |cache| Pipeline.built[1].call(cache) }

    assert_equal([Stryker::Isolation::ForkPerRun, Stryker::Isolation::FreshProcesses], isolations.map(&:class))
  end

  def test_where_the_system_has_no_fork_the_run_stops_before_the_pipeline_starts
    error = assert_raises(Stryker::UnsupportedError) { run_with(forks: false) }

    assert_equal(
      "A run on Windows isn't built yet: Stryker (for Ruby) runs each runtime mutant in a process " \
        "forked from one that loaded the project, and Windows has no fork.",
      error.message
    )
  end

  def test_each_reporter_is_built_once_in_the_order_the_option_names_them
    run_with(reporters: %w[json clear-text json])

    assert_equal([Stryker::Reporters::JsonReport, Stryker::Reporters::ClearText], Pipeline.built.last.map(&:class))
  end

  def test_the_clear_text_reporter_writes_to_standard_output_with_color_when_it_is_a_terminal
    terminal = Terminal.new
    file = StringIO.new
    [terminal, file].each do |stdout|
      run_with(reporters: ["clear-text"], stdout:)
      Pipeline.built.last.first.call(Stryker::Events::RunCompleted.new(results: []))
    end

    assert_equal([true, false], [terminal.string.include?("\e[90m"), file.string.include?("\e[")])
  end

  def test_a_reporter_that_does_not_exist_stops_the_run_with_the_names_of_those_that_do
    error = assert_raises(Stryker::ConfigError) { run_with(reporters: %w[clear-text progress html]) }

    assert_equal(
      'Stryker (for Ruby) has no reporter named "progress" or "html". ' \
        'The reporters option takes "clear-text" and "json".',
      error.message
    )
  end

  def test_a_test_runner_that_does_not_exist_stops_the_run_with_the_names_of_those_that_do
    error = assert_raises(Stryker::ConfigError) { run_with(test_runner: "rspec", reporters: []) }

    assert_equal(
      'Stryker (for Ruby) has no test runner named "rspec". The testRunner option takes "minitest".',
      error.message
    )
  end

  def test_three_names_or_more_are_listed_with_commas
    assert_equal('"a", "b", or "c"', Stryker::CLI::Choice.listed(%w[a b c], "or"))
  end
end
