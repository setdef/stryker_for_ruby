# frozen_string_literal: true

require_relative "pattern_site"

module Stryker
  module Mutators
    module Regex
      def self.name
        "Regex"
      end

      def self.edits(node, ancestors)
        PatternSite.at(node, ancestors).flat_map(&:edits)
      end
    end
  end
end
