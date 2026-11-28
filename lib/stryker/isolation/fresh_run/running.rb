# frozen_string_literal: true

require_relative "reaped"
require_relative "stage"

module Stryker
  module Isolation
    class FreshRun
      class Running < Stage
        def initialize(folder, child, timer)
          super()
          @folder = folder
          @child = child
          @timer = timer
        end

        def check
          # A fresh process writes its messages to a file, so the start of its
          # first test, which starts the run's time limit, shows only there.
          timer = @timer
          timer.tests_started if !timer.testing? && @folder.started?
          nil
        end

        def testing?
          @timer.testing?
        end

        def done?
          @child.ended? || left.zero?
        end

        def wait(seconds)
          @child.wait(seconds)
        end

        def left
          @timer.left
        end

        def reap
          Reaped.new(@folder, @child, @timer, @child.end_within(left))
        end

        def stop
          @child.stop
        ensure
          @folder.remove
        end
      end
    end
  end
end
