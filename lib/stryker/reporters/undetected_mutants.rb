# frozen_string_literal: true

require_relative "mutant_text"
require_relative "tests_ran"

module Stryker
  module Reporters
    class UndetectedMutants
      def initialize(test_names, ink)
        @test_names = test_names
        @ink = ink
      end

      def lines(files)
        files.flat_map { |file| file_lines(file) }
      end

      private def file_lines(file)
        file.mutants.select(&:undetected?).flat_map { |mutant| text(mutant) }
      end

      private def text(mutant)
        MutantText.new(mutant, TestsRan.new(mutant, @test_names), @ink).lines
      end
    end
  end
end
