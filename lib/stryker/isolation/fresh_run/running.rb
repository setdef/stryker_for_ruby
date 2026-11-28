# frozen_string_literal: true

require_relative "reaped"
require_relative "stage"

module Stryker
  module Isolation
    class FreshRun
      class Running < Stage
        POLL_SECONDS = 0.1
        ENDING_SECONDS = 0.01
        public_constant(:ENDING_SECONDS, :POLL_SECONDS)

        def initialize(folder, child, output, timer)
          super()
          @folder = folder
          @child = child
          @output = output
          @timer = timer
        end

        def output
          @output.io
        end

        def take(ready)
          @child.reap unless @output.open?
          # The pipe ends when the process does, unless the process handed its
          # standard output on, or moved it. The system can take a moment more
          # to let an ending process be reaped.
          @output.take(ready) { @child.reap(ENDING_SECONDS) }
          first_test
        end

        def wake_in
          left = @timer.left
          polled? ? [left, POLL_SECONDS].min : left
        end

        def done?
          @child.reaped? || @timer.left.zero?
        end

        def reap
          # Timed out only if the process itself still ran at its deadline.
          timed_out = @child.running?
          @child.end_now
          # What the process wrote before it ended is in the pipe by now. A
          # process that its tests started can hold the pipe open, so this
          # takes what is there and waits for no more.
          @output.finish
          Reaped.new(@folder, @child, @timer, timed_out)
        end

        def stop
          @child.stop
        ensure
          @output.close
          @folder.remove
        end

        private def first_test
          # A fresh process writes its messages to a file, so the start of its
          # first test, which starts the run's time limit, shows only there.
          timer = @timer
          timer.tests_started if !timer.testing? && @folder.started?
          nil
        end

        private def polled?
          # Only the results file shows a test's start, and a process whose
          # pipe ended without its process can end at any moment after.
          !@timer.testing? || !(@output.open? || @child.reaped?)
        end
      end
    end
  end
end
