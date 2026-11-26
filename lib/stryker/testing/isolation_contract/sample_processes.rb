# frozen_string_literal: true

module Stryker
  module Testing
    module IsolationContract
      module SampleProcesses
        def self.running(root)
          alive = Dir.glob(File.join(root, "pids", "*")).reject { |path| ended?(path) }
          alive.map { |path| Integer(File.basename(path), 10) }
        end

        def self.ended?(path)
          # The lock is free once the process that took it has ended, however
          # it ended.
          locked = File.open(path) { |file| file.flock(File::LOCK_EX | File::LOCK_NB) }
          locked.eql?(0)
        end
      end
    end
  end
end
