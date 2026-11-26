# frozen_string_literal: true

module Stryker
  module Runtime
    module OlderRuby
      FIRST_SUPPORTED_MAJOR = 4
      PAGE = "https://github.com/setdef/stryker_for_ruby/blob/trunk/docs/older-ruby.md"
      private_constant(:FIRST_SUPPORTED_MAJOR, :PAGE)

      def self.notify(version = RUBY_VERSION, stream = $stderr)
        # Not Kernel#warn, which `-W0` and `$VERBOSE = nil` silence: a run
        # on a Ruby with known problems has to say so every time.
        stream.puts(message(version)) if Integer(version.split(".").first, 10) < FIRST_SUPPORTED_MAJOR
        nil
      end

      def self.message(version)
        "Stryker (for Ruby) doesn't support Ruby #{version}, which is older than 4.0. " \
          "Problems found on Ruby 3.3 and 3.4 are listed at #{PAGE}"
      end
      private_class_method(:message)
    end
  end
end
