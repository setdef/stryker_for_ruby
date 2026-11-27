# frozen_string_literal: true

require_relative "path_key"

module Stryker
  module Runtime
    class LookupTable < Data.define(:files, :names, :separator)
      def self.of(paths, separator)
        # Under both its keys, because one process gives the hook the real
        # path for a file it finds through $LOAD_PATH or require_relative,
        # and the path as written for an absolute require.
        files = paths
          .map { |path, file| PathKey.of_file(path, separator).to(file) }
          .reduce({}, :merge)
        Ractor.make_shareable(new(files:, names: PathKey.names(files.keys), separator:))
      end

      def file(path)
        own = key(path)
        files[own] || resolved(path, own)
      end

      def instrumented?(path)
        # The real path finds the file as well, because a path through a
        # symbolic link that the table doesn't know names the file too.
        PathKey.of_file(path, separator).any? { |key| files.key?(key) }
      end

      def key(path)
        PathKey.of(path, separator)
      end

      private def resolved(path, own)
        # A load through a second symbolic link, or in another letter case on a
        # file system that folds it, gives a path that the table doesn't have,
        # and a load adds nothing to $LOADED_FEATURES, so the loading check
        # can't see the miss. The real path costs a system call, so it is
        # resolved only for a file whose base name an instrumented file has, and
        # the hook pays it for no other file.
        return unless names.include?(PathKey.name(own))

        files[PathKey.of_file(PathKey.located(path), separator).resolved]
      end

      private_class_method(:new)

      # @dynamic files, names, separator
    end
  end
end
