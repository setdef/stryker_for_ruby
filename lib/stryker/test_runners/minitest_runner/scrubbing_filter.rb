# frozen_string_literal: true

module Stryker
  module TestRunners
    class MinitestRunner
      class ScrubbingFilter
        def self.around
          filter = ::Minitest.backtrace_filter
          begin
            ::Minitest.backtrace_filter = new(filter)
            yield
          ensure
            ::Minitest.backtrace_filter = filter
          end
        end

        def initialize(filter)
          @filter = filter
        end

        def filter(lines)
          @filter.filter(lines.map(&:scrub))
        end
      end
    end
  end
end
