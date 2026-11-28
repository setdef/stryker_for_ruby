# frozen_string_literal: true

require_relative("cli/failures")
require_relative("cli/information")
require_relative("cli/mutation_testing")
require_relative("cli/output")
require_relative("cli/run")
require_relative("cli/run_command")
require_relative("cli/streams")

module Stryker
  class CLI
    def self.call(argv, **settings)
      new(**settings).call(argv)
    end

    def initialize(stdout: $stdout, stderr: $stderr, env: ENV.to_h, root: Dir.pwd, pipeline: MutationTesting.new(root))
      @streams = Streams.new(Output.new(stdout), Output.new(stderr))
      @failures = Failures.new(@streams.stderr)
      @information = Information.new(@streams)
      run = Run.new(pipeline:, streams: @streams, env:, root:)
      @run = RunCommand.new(run:, streams: @streams, information: @information)
    end

    def call(argv)
      # Standard output holds what the command wrote until a flush, so the
      # flush is where a reader that has gone shows.
      @failures.guard { dispatch(*argv).tap { @streams.flush } }
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
