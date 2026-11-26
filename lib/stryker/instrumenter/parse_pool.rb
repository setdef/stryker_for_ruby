# frozen_string_literal: true

require "rbconfig"
require_relative "parse_batch"
require_relative "parse_worker_process"

module Stryker
  class Instrumenter
    class ParsePool
      THRESHOLD = 20_000_000
      WORKER = File.expand_path("parse_worker", File.dirname(__FILE__))
      COMMAND = [RbConfig.ruby, "-r", WORKER, "-e", "Stryker::Instrumenter::ParseWorker.serve"].freeze
      public_constant(:THRESHOLD)
      private_constant(:COMMAND, :WORKER)

      def self.open(concurrency, threshold = THRESHOLD, command = COMMAND)
        pool = new(concurrency, threshold, command)
        begin
          yield(pool)
        ensure
          pool.stop
        end
      end

      def initialize(concurrency, threshold = THRESHOLD, command = COMMAND)
        @concurrency = concurrency
        @threshold = threshold
        @command = command
        @workers = []
      end

      def valid(source, plains)
        return plains.map { |plain| plain.valid?(source) } unless parallel?(source.bytesize * plains.size)

        checked(source, plains)
      end

      def stop
        @workers.each(&:stop)
        @workers = []
      end

      private def parallel?(work)
        @concurrency > 1 && work >= @threshold
      end

      private def checked(source, plains)
        start if @workers.empty?
        ParseBatch.new(source, plains, @workers).run
      rescue
        stop
        raise
      end

      private def start
        @concurrency.times { @workers << ParseWorkerProcess.start(@command) }
      end
    end
  end
end
