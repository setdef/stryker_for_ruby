# frozen_string_literal: true

require_relative "stage"

module Stryker
  module Isolation
    class FreshRun
      class Made < Stage
        def initialize(folder)
          super()
          @folder = folder
        end

        def spawn(launch, run, recipe)
          launch.call(@folder, run, recipe)
        end

        def stop
          @folder.remove
        end
      end
    end
  end
end
