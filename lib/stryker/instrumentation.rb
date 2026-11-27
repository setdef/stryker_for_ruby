# frozen_string_literal: true

require_relative "instrumentation/result"
require_relative "instrumentation/source_file"
require_relative "instrumenter"
require_relative "mutators"
require_relative "unsupported_error"

module Stryker
  class Instrumentation
    TEMPLATE = ".erb"
    TEMPLATES = "Stryker (for Ruby) doesn't mutate ERB templates, and the mutate option selects %<path>s. " \
      'Leave templates out with a pattern such as "!**/*.erb".'
    private_constant(:TEMPLATE, :TEMPLATES)

    def initialize(root, config, mutators = Mutators::ALL)
      excluded = config.excluded_mutations
      @root = root
      @concurrency = config.concurrency
      @mutators = mutators.reject { |mutator| excluded.include?(mutator.name) }
    end

    def call(paths)
      template = paths.find { |path| File.extname(path).casecmp?(TEMPLATE) }
      raise(UnsupportedError, format(TEMPLATES, path: template)) if template

      Instrumenter::ParsePool.open(@concurrency) { |pool| instrument(paths, pool) }
    end

    private def instrument(paths, pool)
      files = paths.each_with_object([]) do |path, done|
        done << SourceFile.new(@root, path).instrumented(pool, @mutators, InstrumentedFile.next_id(done))
      end
      Result.of(files)
    end
  end
end
