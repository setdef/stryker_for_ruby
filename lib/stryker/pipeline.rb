# frozen_string_literal: true

require "tmpdir"
require_relative "events/run_aborted"
require_relative "events/run_completed"
require_relative "instrumentation"
require_relative "metrics"
require_relative "pipeline/broadcast"
require_relative "pipeline/isolations"
require_relative "pipeline/raised"
require_relative "pipeline/selected_files"
require_relative "pipeline/trial"
require_relative "runtime/cache"

module Stryker
  class Pipeline
    CACHE = "stryker-cache-"
    private_constant(:CACHE)

    def initialize(root, isolations, reporters, warnings: $stderr)
      @root = root
      @warnings = warnings
      @isolations = isolations
      @broadcast = Broadcast.new(reporters)
    end

    def call(config)
      # @type var results: Array[MutantResult]
      results = []
      aborted(Raised.by { results = completed(config) })
      Metrics.count(results.map(&:status)).mutation_score
    end

    private def completed(config)
      results = run_stages(config)
      @broadcast.call(Events::RunCompleted.new(results:)) unless results.equal?(Trial::NOTHING_TESTED)
      results
    end

    private def run_stages(config)
      instrumented = instrument(config)
      Dir.mktmpdir(CACHE) { |cache| tested(config, cache, instrumented) }
    end

    private def aborted(error)
      return unless error

      # The error that stopped the run leaves, not one that a reporter raised
      # as it heard so.
      Raised.by { @broadcast.call(Events::RunAborted.new(error:)) }
      raise(error)
    end

    private def instrument(config)
      Instrumentation.new(@root, config, warnings: @warnings).call(SelectedFiles.new(@root, config).to_a)
    end

    private def tested(config, cache, instrumented)
      Runtime::Cache.write(cache, instrumented.sources)
      runtime, static = @isolations.call(cache)
      isolations = Isolations.new(runtime:, static:)
      isolations.open(config) { Trial.new(config, @broadcast).call(isolations, instrumented) }
    end
  end
end
