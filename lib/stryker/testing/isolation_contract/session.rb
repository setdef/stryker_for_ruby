# frozen_string_literal: true

require_relative "../../config"
require_relative "sample_processes"

module Stryker
  module Testing
    module IsolationContract
      class Session
        def initialize(host, sample, concurrency)
          @sample = sample
          @isolation = host.isolation_under_test(sample.cache, sample.root)
          @isolation.start(Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", concurrency:))
        end

        def results(*batches)
          results = batches.flat_map { |runs| collected(runs) }
          results.to_h { |result| [result.mutant.id, result] }
        ensure
          @isolation.stop
        end

        def running_after_a_raise
          @isolation.run_all(@sample.hanging_runs) { raise(StopIteration) }
        rescue StopIteration
          # Before stop, which would end them anyway.
          SampleProcesses.running(@sample.root)
        ensure
          @isolation.stop
        end

        private def collected(runs)
          # @type var results: Array[MutantResult]
          results = []
          @isolation.run_all(runs) { |result| results << result }
          results
        end
      end
    end
  end
end
