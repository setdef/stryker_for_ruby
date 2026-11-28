# frozen_string_literal: true

require "tmpdir"
require_relative "events/run_aborted"
require_relative "events/run_completed"
require_relative "instrumentation"
require_relative "metrics"
require_relative "pipeline/broadcast"
require_relative "pipeline/isolations"
require_relative "pipeline/outcome"
require_relative "pipeline/raised"
require_relative "pipeline/selected_files"
require_relative "pipeline/trial"
require_relative "runtime/cache"

module Stryker
  class Pipeline
    CACHE = "stryker-cache-"
    NOTHING_TESTED = "The dry run found no test, so, as allowEmpty is true, " \
      "no mutant was tested and no report was written."
    private_constant(:CACHE, :NOTHING_TESTED)

    def initialize(root, isolations, reporters, warnings: $stderr)
      @root = root
      @warnings = warnings
      @isolations = isolations
      @broadcast = Broadcast.new(reporters)
    end

    def call(config)
      # @type var results: Array[MutantResult]
      results = []
      aborted(Raised.by { results = run_stages(config).tell(self) })
      Metrics.count(results.map(&:status)).mutation_score
    end

    def completed(results)
      @broadcast.call(Events::RunCompleted.new(results:))
    end

    def nothing_tested
      @warnings.puts(NOTHING_TESTED)
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
