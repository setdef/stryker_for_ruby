# frozen_string_literal: true

require_relative "path_key"

module Stryker
  module Runtime
    class LookupTable < Data.define(:files, :names, :separator)
      def self.of(files, separator)
        Ractor.make_shareable(new(files:, names: PathKey.names(files.keys), separator:))
      end

      def file(path)
        key = PathKey.of(path, separator)
        files[key] || resolved(path, key)
      end

      private def resolved(path, key)
        # A load through a second symbolic link, or in another letter case on a
        # file system that folds it, gives a path that the table doesn't have,
        # and a load adds nothing to $LOADED_FEATURES, so the loading check
        # can't see the miss. The real path costs a system call, so it is
        # resolved only for a file whose base name an instrumented file has, and
        # the hook pays it for no other file. The last key is the real path's,
        # or the path's own when there is no real path.
        return unless names.include?(PathKey.name(key))

        files[PathKey.of_file(PathKey.located(path), separator).last]
      end

      # @dynamic files, names, separator
    end
  end
end
