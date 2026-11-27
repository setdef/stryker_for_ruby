# frozen_string_literal: true

require_relative "../instrumenter"
require_relative "../mutators/walk"
require_relative "../source_error"
require_relative "instrumented_file"

module Stryker
  class Instrumentation
    class SourceFile
      def initialize(root, path)
        @path = path
        @absolute = File.absolute_path(path, root)
      end

      def instrumented(pool, mutators, first_id)
        source = File.binread(@absolute).force_encoding(Encoding::UTF_8)
        parsed = Instrumenter::Syntax.parse(source)
        raise(SourceError.unparsable(@path, parsed.errors.first)) unless parsed.success?

        mutants = Mutators::Walk.new(file: @path, result: parsed, mutators:, first_id:).mutants
        InstrumentedFile.of(@absolute, mutants, Instrumenter.new(source, pool).instrument(mutants))
      end
    end
  end
end
