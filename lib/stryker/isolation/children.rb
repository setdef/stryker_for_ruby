# frozen_string_literal: true

require_relative "../runtime"
require_relative "child"
require_relative "timer"
require_relative "watch"
require_relative "watches"

module Stryker
  module Isolation
    class Children
      def initialize(forking, relay)
        @forking = forking
        @relay = relay
        @watches = Watches.new
      end

      def start(run, work)
        # The hits that the project's Ractors made while it loaded go into
        # the static bucket that the child inherits.
        Runtime::RECORDER.drain
        pid, reader = @forking.start(run, work)
        @relay.forked(run, pid)
        @watches.add(Watch.new(run, Child.new(pid), reader, Timer.new(run.timeout_ms)))
      end

      def wait(commands)
        readable, ended = @watches.wait([commands]) { |run, line| @relay.message(run, line) }
        ended.each { |run, ending| @relay.exited(run, ending.with(errors: @forking.errors(run))) }
        readable
      end

      def stop
        @watches.stop
      end
    end
  end
end
