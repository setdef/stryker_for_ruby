# frozen_string_literal: true

require_relative "branch"
require_relative "site"
require_relative "skip"

module Stryker
  class Instrumenter
    # steep:ignore:start
    class Outcome < Data.define(:mutant, :node, :text, :valid)
      # steep:ignore:end
      def site
        return unless node && text

        location = node.location
        Site.new(
          start_offset: location.start_offset,
          end_offset: location.end_offset,
          branches: [Branch.new(id: mutant.id, text:)]
        )
      end

      def skip
        return if text

        Skip.new(mutant:, reason:)
      end

      private def reason
        return :does_not_parse unless valid

        node ? :no_one_line_form : :no_switch_site
      end
    end
  end
end
