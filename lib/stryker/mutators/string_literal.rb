# frozen_string_literal: true

require_relative "../edit"
require_relative "string_site"

module Stryker
  module Mutators
    module StringLiteral
      EMPTIED = '""'
      private_constant(:EMPTIED)

      FILLER = '"Stryker was here!"'
      private_constant(:FILLER)

      def self.name
        "StringLiteral"
      end

      def self.edits(node, ancestors)
        site = StringSite.of(node, ancestors)
        return [] unless site

        [Edit.over(node.location, site.empty? ? FILLER : EMPTIED)]
      end
    end
  end
end
