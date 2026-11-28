# frozen_string_literal: true

# The runtime first: with STRYKER_ACTIVE_MUTANT set, it makes that mutant
# active before any of the project's code loads.
require_relative "../runtime"
require_relative "../test_runners"
require_relative "fork_parent"
require_relative "fresh_process"
require_relative "process_words"

module Stryker
  module Isolation
    module ProjectProcess
      MODES = { "fork-parent": ForkParent, fresh: FreshProcess }.transform_keys(&:to_s).freeze
      public_constant(:MODES)

      def self.main(argv = ARGV, loader = Runtime::Loader, modes = MODES)
        # Every argument leaves ARGV before the project's code loads, so
        # Minitest, which parses ARGV as its options, never sees one.
        words = ProcessWords.take(argv)
        loader.install(words.directory.to_s)
        words.build(modes, Dir.pwd).call
      end
    end
  end
end
