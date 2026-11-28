# frozen_string_literal: true

require "English"
require_relative "../file_name"
require_relative "candidate"
require_relative "traversal"
require_relative "unreadable"

module Stryker
  module Mutators
    class Search
      def initialize(result, file, mutators, warnings)
        raise(ArgumentError, "#{file} doesn't parse, so it has no sites") unless result.success?

        @tree = result.value
        @file = file
        @mutators = mutators
        @warnings = warnings
      end

      def candidates
        @mutators.flat_map { |mutator| Candidate.in_order(candidates_of(mutator)) }
      end

      private def candidates_of(mutator)
        # @type var found: Array[Candidate]
        found = []
        Traversal.new(@tree).each { |node, ancestors| found.concat(candidates_at(mutator, node, ancestors)) }
        found
      end

      private def candidates_at(mutator, node, ancestors)
        Candidate.at(mutator, node, ancestors)
      rescue Unreadable
        @warnings.puts("#{FileName.shown(@file)}:#{node.location.start_line}: warning: #{$ERROR_INFO}")
        []
      end
    end
  end
end
