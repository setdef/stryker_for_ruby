# frozen_string_literal: true

require_relative "path_key"

module Stryker
  module Runtime
    module Stack
      TOP_LEVEL_LABELS = Ractor.make_shareable(Set["<compiled>", "<top (required)>", "<main>"])
      private_constant(:TOP_LEVEL_LABELS)

      def self.loading?(paths, separator = File::ALT_SEPARATOR)
        # The whole stack, not caller_locations(1, n), which misses a
        # top-level frame deeper than n. The path comes before the label
        # because reading the label first costs about three times as much on
        # Ruby 3.4 and 4.0. The label counts as well as the path because a
        # method that the file defines, and a C method such as Array#each
        # that one of them calls, report the file's path too. The path is
        # tagged as the keys are, because under the C locale Ruby tags it
        # US-ASCII, and a Hash finds a key only in the same encoding.
        Thread.each_caller_location do |location|
          path = location.absolute_path
          path = PathKey.of(path, separator) if path && (separator || path.encoding != Encoding::UTF_8)
          return true if paths.include?(path) && TOP_LEVEL_LABELS.include?(location.label)
        end
        false
      end
    end
  end
end
