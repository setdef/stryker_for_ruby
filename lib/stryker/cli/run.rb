# frozen_string_literal: true

require_relative("../config_error")
require_relative("../configure")
require_relative("color")
require_relative("failures")
require_relative("verdict")

module Stryker
  class CLI
    class Run
      def initialize(pipeline:, streams:, env:, root:)
        @pipeline = pipeline
        @streams = streams
        @env = env
        @root = root
      end

      def call(options:, file:, no_color:)
        Failures.new(@streams.stderr).guard { execute(options, file, no_color) }
      end

      private def execute(options, file, no_color)
        raise(ConfigError, %(The configuration file #{file.inspect} has a NUL byte.)) if file&.include?("\0")

        config = Configure.call(options:, file:, root: @root)
        score = @pipeline.call(config, @streams, Color.from(@env, no_color))
        Verdict.new(config.threshold_break).status(score)
      end
    end
  end
end
