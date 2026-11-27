# frozen_string_literal: true

require_relative "../two_decimals"

module Stryker
  module Reporters
    class FileTree
      class Row < Data.define(:name, :depth, :file, :metrics)
        def count(member)
          metrics.public_send(member)
        end

        def score(kind)
          metrics.public_send(kind)
        end

        def score_text(kind)
          value = score(kind)
          value ? TwoDecimals.of(value) : "n/a"
        end

        def errors
          count(:runtime_errors) + count(:compile_errors)
        end

        # @dynamic name, depth, file, metrics
      end
    end
  end
end
