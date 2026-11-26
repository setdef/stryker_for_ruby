# frozen_string_literal: true

module Stryker
  module Runtime
    module Stack
      TOP_LEVEL_LABELS = Ractor.make_shareable(Set["<compiled>", "<top (required)>", "<main>"])
      public_constant(:TOP_LEVEL_LABELS)

      def self.loading?(paths)
        # The whole stack, not caller_locations(1, n), which misses a
        # top-level frame deeper than n. The path comes before the label
        # because reading the label first costs about three times as much on
        # Ruby 3.4 and 4.0. The label counts as well as the path because a
        # method that the file defines, and a C method such as Array#each
        # that one of them calls, report the file's path too.
        Thread.each_caller_location do |location|
          return true if paths.include?(location.absolute_path) && TOP_LEVEL_LABELS.include?(location.label)
        end
        false
      end

      def self.frame_paths(path)
        # Ruby gives the hook the path it resolved, which can hold a symbolic
        # link or "..", and gives the frames of a file it compiles itself the
        # real path. A file the hook compiles gets the path the hook gave.
        [path, File.realpath(path)]
      rescue SystemCallError
        [path]
      end
    end
  end
end
