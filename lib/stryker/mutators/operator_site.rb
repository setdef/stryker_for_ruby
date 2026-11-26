# frozen_string_literal: true

require_relative "../edit"
require_relative "node_text"
require_relative "operator_call"

module Stryker
  module Mutators
    module OperatorSite
      module Reading
        def of(node, names)
          call = OperatorCall.of(node, names)
          written(call) if call
        end

        def edits(node, table, &)
          Array(of(node, table.keys)&.edits(table, &))
        end
      end
      private_constant(:Reading)

      def self.included(base)
        base.extend(Reading)
      end

      def operator
        call.name
      end

      def edits(table)
        return [] if yield(self)

        table.fetch(operator, []).map { |replacement| replacement ? with_operator(replacement) : dropped }
      end

      private def dropped
        Edit.over(call.location, receiver.slice)
      end

      private def with_operator(replacement)
        Edit.over(call.location, NodeText.replacing(call, [[operator_loc, replacement]]))
      end
    end
  end
end
