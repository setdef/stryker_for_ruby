# frozen_string_literal: true

require "optparse"

module Stryker
  class CLI
    class Complaint
      def initialize(flags, error)
        @flags = flags
        @error = error
        @flag = error.args.first.split("=").first
      end

      def to_s
        case @error
        when OptionParser::InvalidOption then unknown
        when OptionParser::MissingArgument then "The flag #{@flag} needs a value."
        else "The flag #{@flag} takes no value."
        end
      end

      private def unknown
        nearest = @flags.suggest(@flag)
        hint = nearest && " Did you mean #{nearest}?"
        "Unknown flag #{@flag}.#{hint}"
      end
    end
  end
end
