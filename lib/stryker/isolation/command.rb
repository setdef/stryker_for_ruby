# frozen_string_literal: true

require "rbconfig"

module Stryker
  module Isolation
    module Command
      ENTRY = File.expand_path("project_process.rb", File.dirname(__FILE__))
      MAIN = "Stryker::Isolation::ProjectProcess.main"
      ACTIVE_MUTANT = "STRYKER_ACTIVE_MUTANT"
      public_constant(:ACTIVE_MUTANT, :ENTRY, :MAIN)

      def self.for(*arguments)
        # An array of arguments, so no shell parses a path. Ruby's own options
        # end at "--", and the rest reach ARGV, which the entry point empties.
        [RbConfig.ruby, "-r", ENTRY, "-e", MAIN, "--", *arguments]
      end

      def self.environment(id = nil)
        # With no ID, the variable is unset, whatever the orchestrator's own
        # environment holds, so no mutant is active.
        { ACTIVE_MUTANT => id&.to_s }
      end
    end
  end
end
