# frozen_string_literal: true

require_relative "ink"
require_relative "summary"
require_relative "whole_run"

module Stryker
  module Reporters
    class ClearText < WholeRun
      def initialize(config:, root:, io:, color:)
        super(config:, root:)
        @io = io
        @ink = Ink.new(enabled: color)
        @high = config.threshold_high
        @low = config.threshold_low
      end

      private def publish(report)
        @io.write(Summary.new(report, ink: @ink, high: @high, low: @low).to_s)
      end
    end
  end
end
