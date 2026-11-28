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
        # tagged as the keys are when it has a byte beyond ASCII, because
        # under the C locale Ruby tags it US-ASCII or binary, and a Hash finds
        # a key of such a path only in the same encoding. A path of ASCII
        # bytes finds its key whatever its tag, which string.c's
        # rb_str_hash_cmp, rb_str_comparable, and str_do_hash say, so it is
        # not copied.
        Thread.each_caller_location do |location|
          path = location.absolute_path
          if path && (separator || (path.encoding != Encoding::UTF_8 && !path.ascii_only?))
            path = PathKey.of(path, separator)
          end
          return true if paths.include?(path) && TOP_LEVEL_LABELS.include?(location.label)
        end
        false
      end
    end
  end
end
