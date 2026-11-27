# frozen_string_literal: true

require_relative "../mutant_result"

module Stryker
  class Instrumenter
    class Skip < Data.define(:mutant, :reason)
      IGNORED = {
        no_switch_site: "The site can't hold a switch, so no test can run with this mutant.",
        no_one_line_form: "The mutant has no form on one line, so no test can run with this mutant.",
      }.freeze
      private_constant(:IGNORED)

      def result
        return MutantResult.unrun(mutant, "CompileError") if reason == :does_not_parse

        MutantResult.unrun(mutant, "Ignored", IGNORED[reason])
      end

      # @dynamic mutant, reason
    end
  end
end
