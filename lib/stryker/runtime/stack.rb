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
        # that one of them calls, report the file's path too.
        Thread.each_caller_location do |location|
          path = location.absolute_path
          path = PathKey.of(path, separator) if separator && path
          return true if paths.include?(path) && TOP_LEVEL_LABELS.include?(location.label)
        end
        false
      end

      def self.frame_paths(path, separator = File::ALT_SEPARATOR)
        # Ruby gives the hook the path it resolved, which can hold a symbolic
        # link or "..", and gives the frames of a file it compiles itself the
        # real path. A file the hook compiles gets the path the hook gave.
        [path, File.realpath(path)].map { |form| PathKey.of(form, separator) }
      rescue SystemCallError
        [PathKey.of(path, separator)]
      end
    end
  end
end
