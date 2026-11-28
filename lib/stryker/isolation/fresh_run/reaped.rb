# frozen_string_literal: true

require_relative "../ending"
require_relative "stage"

module Stryker
  module Isolation
    class FreshRun
      class Reaped < Stage
        def initialize(folder, child, timer, timed_out)
          super()
          @folder = folder
          @child = child
          @timer = timer
          @timed_out = timed_out
        end

        def land(landing)
          ending = Ending.of(status, timed_out: @timed_out, duration_ms: @timer.elapsed_ms)
          landing.call(@folder.messages, ending.with(errors: @folder.errors))
          nil
        ensure
          @folder.remove
        end

        def stop
          @folder.remove
        end

        private def status
          @child.status
        ensure
          # What its tests started dies with it, whether or not the status
          # could be read. Only here: the process has been reaped, and a stop
          # from here on leaves its group alone, whose ID may belong to another
          # process by then.
          @child.kill_rest
        end
      end
    end
  end
end
