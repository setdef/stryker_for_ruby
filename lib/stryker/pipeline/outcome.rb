# frozen_string_literal: true

module Stryker
  class Pipeline
    module Outcome
      class Tested
        def initialize(results)
          @results = results
        end

        def tell(listener)
          listener.completed(@results)
          @results
        end
      end

      class Untested
        def initialize
          @results = []
        end

        def tell(listener)
          listener.nothing_tested
          @results
        end
      end

      def self.tested(results)
        Tested.new(results)
      end

      def self.untested
        Untested.new
      end
    end
  end
end
