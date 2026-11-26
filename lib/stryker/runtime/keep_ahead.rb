# frozen_string_literal: true

require_relative "hook"

module Stryker
  module Runtime
    module KeepAhead
      def prepend(*modules)
        super
        # Bootsnap's load_iseq doesn't call super, so whatever it serves
        # would hide the instrumented source.
        super(Hook.copy) if modules.any? { |mod| Hook.rival?(mod) }
        self
      end
    end
  end
end
