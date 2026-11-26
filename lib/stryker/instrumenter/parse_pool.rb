# frozen_string_literal: true

require "rbconfig"
require_relative "parse_batch"
require_relative "parse_worker_process"

module Stryker
  class Instrumenter
    class ParsePool
      WORK_PER_WORKER = 40_000_000
      WORKER = File.expand_path("parse_worker", File.dirname(__FILE__))
      COMMAND = [RbConfig.ruby, "-r", WORKER, "-e", "Stryker::Instrumenter::ParseWorker.serve"].freeze
      public_constant(:WORK_PER_WORKER)
      private_constant(:COMMAND, :WORKER)

      def self.open(concurrency, work_per_worker = WORK_PER_WORKER, command = COMMAND)
        pool = new(concurrency, work_per_worker, command)
        begin
          yield(pool)
        ensure
          pool.stop
        end
      end

      def initialize(concurrency, work_per_worker = WORK_PER_WORKER, command = COMMAND)
        @concurrency = concurrency
        @work_per_worker = work_per_worker
        @command = command
        @workers = []
      end

      def valid(source, plains)
        count = [@concurrency, source.bytesize * plains.size / @work_per_worker].min
        return plains.map { |plain| plain.valid?(source) } if count < 2

        checked(source, plains, count)
      end

      def stop
        @workers.each(&:stop)
        @workers = []
      end

      private def checked(source, plains, count)
        start(count)
        ParseBatch.new(source, plains, @workers.first(count)).run
      rescue
        stop
        raise
      end

      private def start(count)
        (count - @workers.size).times { @workers << ParseWorkerProcess.start(@command) }
      end
    end
  end
end
