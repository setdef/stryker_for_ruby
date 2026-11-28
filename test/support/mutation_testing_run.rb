# frozen_string_literal: true

require_relative("../test_helper")
require "stringio"
require "stryker/cli/color"
require "stryker/cli/mutation_testing"
require "stryker/cli/streams"
require "stryker/config"

# Runs the command's mutation testing in this process, with a pipeline that
# records what it is given.
module MutationTestingRun
  # Stands in for Stryker::Pipeline: records what it was built with, and
  # gives a score.
  class Pipeline
    class << self
      attr_reader :built, :config, :warnings
    end

    def initialize(root, isolations, reporters, warnings:)
      self.class.instance_variable_set(:@built, [root, isolations, reporters])
      self.class.instance_variable_set(:@warnings, warnings)
    end

    def call(config)
      self.class.instance_variable_set(:@config, config)
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

  def run_with(forks: true, stdout: StringIO.new, stderr: StringIO.new, color: Stryker::CLI::Color.new(false), **)
    testing = Stryker::CLI::MutationTesting.new("/project", forks:, pipeline: Pipeline)
    testing.call(config(**), Stryker::CLI::Streams.new(stdout, stderr), color)
  end
end
