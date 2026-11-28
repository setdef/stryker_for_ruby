# frozen_string_literal: true

require_relative "../events/run_completed"

module Stryker
  class Pipeline
    module Outcome
      class Tested
        attr_reader :results

        def initialize(results)
          @results = results
        end

        def announce(broadcast, _warnings)
          broadcast.call(Events::RunCompleted.new(results:))
        end

        # @dynamic results
      end

      module Untested
        LINE = "The dry run found no test, so, as allowEmpty is true, no mutant was tested and no report was written."
        private_constant(:LINE)

        def self.results
          Array(nil)
        end

        def self.announce(_broadcast, warnings)
          warnings.puts(LINE)
        end
      end

      def self.tested(results)
        Tested.new(results)
      end

      def self.untested
        Untested
      end
    end
  end
end
