# frozen_string_literal: true

require "tmpdir"
require_relative "events/run_completed"
require_relative "instrumentation"
require_relative "metrics"
require_relative "pipeline/broadcast"
require_relative "pipeline/isolations"
require_relative "pipeline/trial"
require_relative "runtime/cache"
require_relative "source_files"

module Stryker
  class Pipeline
    CACHE = "stryker-cache-"
    private_constant(:CACHE)

    def initialize(root, isolations, reporters)
      @root = root
      @isolations = isolations
      @broadcast = Broadcast.new(reporters)
    end

    def call(config)
      instrumented = Instrumentation.new(@root, config).call(SourceFiles.new(@root, config.mutate).to_a)
      results = Dir.mktmpdir(CACHE) { |cache| tested(config, cache, instrumented) }
      @broadcast.call(Events::RunCompleted.new(results:))
      Metrics.count(results.map(&:status)).mutation_score
    end

    private def tested(config, cache, instrumented)
      Runtime::Cache.write(cache, instrumented.sources)
      runtime, static = @isolations.call(cache)
      isolations = Isolations.new(runtime:, static:)
      isolations.open(config) { Trial.new(config, @broadcast).call(isolations, instrumented) }
    end
  end
end
