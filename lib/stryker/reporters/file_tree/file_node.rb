# frozen_string_literal: true

require_relative "../../metrics"
require_relative "row"

module Stryker
  module Reporters
    class FileTree
      class FileNode
        def initialize(name, leaf)
          @name = name
          @leaf = leaf
        end

        def statuses
          @leaf.statuses
        end

        def rows(depth)
          [Row.new(name: @name, depth:, file: @leaf.file, metrics: Metrics.count(statuses))]
        end
      end
    end
  end
end
