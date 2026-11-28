# frozen_string_literal: true

require_relative "child"
require_relative "process_group"

module Stryker
  module Isolation
    class Custody
      def initialize(fresh, process = Process)
        @fresh = fresh
        @process = process
        @pid = nil
        @child = nil
      end

      def around
        # @type var returned: bool
        returned = false
        # A signal waits until the block has ended, and then raises before
        # the block's value returns, so the ensure clause ends the process
        # however the launch fails.
        held = Thread.handle_interrupt(Object => :never) { yield(self) }
        returned = true
        held
      ensure
        abandon unless returned
      end

      def child(pid)
        @pid = pid
        @child = Child.new(pid, @process)
      end

      private def abandon
        # The folder outlives the process, which writes into it.
        end_process
      ensure
        @fresh.remove
      end

      private def end_process
        child = @child
        return child.stop if child

        pid = @pid or return
        ProcessGroup.kill(pid, @process)
        @process.wait(pid)
      end
    end
  end
end
