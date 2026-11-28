# frozen_string_literal: true

require_relative "../child"
require_relative "../process_group"
require_relative "../timer"
require_relative "running"
require_relative "stage"

module Stryker
  module Isolation
    class FreshRun
      class Spawned < Stage
        def initialize(folder, pid, process = Process)
          super()
          @folder = folder
          @pid = pid
          @process = process
        end

        def hold(timeout_ms)
          Running.new(@folder, Child.new(@pid, @process), Timer.new(timeout_ms))
        end

        def stop
          # The folder outlives the process, which writes into it.
          ProcessGroup.kill(@pid, @process)
          @process.wait(@pid)
        ensure
          @folder.remove
        end
      end
    end
  end
end
