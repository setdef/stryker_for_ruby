# frozen_string_literal: true

require_relative("../reporters/clear_text")
require_relative("../reporters/json_report")
require_relative("choice")
require_relative("unbuilt_reporters")

module Stryker
  class CLI
    class Reporting
      CLEAR_TEXT = "clear-text"
      NAMES = [CLEAR_TEXT, "json"].freeze
      CHOICE = Choice.new("reporters", "reporter", NAMES)
      private_constant(:CLEAR_TEXT, :NAMES, :CHOICE)

      def initialize(config, root)
        @config = config
        @root = root
      end

      def reporters(streams, color)
        names(streams.stderr).map { |name| (name == CLEAR_TEXT) ? clear_text(streams.stdout, color) : json }
      end

      private def names(stderr)
        @config.given.include?(:reporters) ? named : defaulted(stderr)
      end

      private def named
        CHOICE.check(listed)
        listed
      end

      private def defaulted(stderr)
        unbuilt = listed - NAMES
        stderr.puts(UnbuiltReporters.new(unbuilt)) unless unbuilt.empty?
        listed - unbuilt
      end

      private def listed
        @config.reporters.uniq
      end

      private def clear_text(stdout, color)
        Reporters::ClearText.new(config: @config, root: @root, io: stdout, color: color.enabled_for?(stdout))
      end

      private def json
        Reporters::JsonReport.new(config: @config, root: @root)
      end
    end
  end
end
