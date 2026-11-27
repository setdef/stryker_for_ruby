# frozen_string_literal: true

require_relative("../reporters/clear_text")
require_relative("../reporters/json_report")
require_relative("choice")

module Stryker
  class CLI
    class Reporting
      CLEAR_TEXT = "clear-text"
      NAMES = [CLEAR_TEXT, "json"].freeze
      private_constant(:CLEAR_TEXT, :NAMES)

      def initialize(config, root)
        @config = config
        @root = root
      end

      def reporters(stdout, color)
        names = @config.reporters.uniq
        Choice.new("reporters", "reporter", NAMES).check(names)
        names.map { |name| (name == CLEAR_TEXT) ? clear_text(stdout, color) : json }
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
