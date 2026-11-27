# frozen_string_literal: true

require_relative("choice")

module Stryker
  class CLI
    class UnbuiltReporters
      def initialize(names)
        @names = names
      end

      def to_s
        many = @names.size > 1
        "Warning: this run leaves out the default #{many ? 'reporters' : 'reporter'} " \
          "#{Choice.listed(@names, 'and')}, because Stryker (for Ruby) hasn't built #{many ? 'them' : 'it'} yet. " \
          "Name the reporters you want, as in --reporters clear-text,json, to choose your own."
      end
    end
  end
end
