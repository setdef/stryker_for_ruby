# frozen_string_literal: true

require_relative("cli/failures")
require_relative("cli/information")
require_relative("cli/mutation_testing")
require_relative("cli/run")
require_relative("cli/run_command")
require_relative("cli/streams")

module Stryker
  class CLI
    def self.call(argv, **settings)
      new(**settings).call(argv)
    end

    def initialize(stdout: $stdout, stderr: $stderr, env: ENV.to_h, root: Dir.pwd, pipeline: MutationTesting.new(root))
      streams = Streams.new(stdout, stderr)
      @failures = Failures.new(stderr)
      @information = Information.new(streams)
      @run = RunCommand.new(run: Run.new(pipeline:, streams:, env:, root:), streams:)
    end

    def call(argv)
      @failures.guard { dispatch(*argv) }
    end

    private def dispatch(command = nil, *rest)
      case command
      when "run" then @run.call(rest)
      when "help" then help(rest.first)
      when "-h", "--help" then help(nil)
      when "--version" then @information.version
      else @information.unknown(command)
      end
    end

    private def help(topic)
      (topic == "run") ? @run.call(%w[--help]) : @information.help(topic)
    end
  end
end
