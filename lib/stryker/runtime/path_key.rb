# frozen_string_literal: true

module Stryker
  module Runtime
    module PathKey
      def self.of(path, separator = File::ALT_SEPARATOR)
        # Ruby on Windows can give the same file with a different drive
        # letter, letter case, or separator. Elsewhere a path is compared as
        # it is, because a case-sensitive file system has files that differ
        # only in case.
        # The bytes are tagged UTF-8 whatever Ruby tagged them, because a
        # Hash finds a key only in the same encoding. Under the C locale Ruby
        # tags a path from the file system US-ASCII, and the cache's index
        # reads as UTF-8.
        key = path.dup.force_encoding(Encoding::UTF_8)
        separator ? key.tr(separator, "/").downcase : key
      end

      def self.of_file(path, separator = File::ALT_SEPARATOR)
        # Ruby gives the hook the path it resolved, which can hold a symbolic
        # link or "..", and gives a file it compiles itself the real path, in
        # its frames and in $LOADED_FEATURES.
        real = real(path)
        (real ? [path, real] : [path]).map { |form| of(form, separator) }
      end

      def self.located(path)
        # A load that Ruby finds relative to the working directory gives the
        # hook the path as it was written, and Ruby resolves it against the
        # working directory when it opens the file. The loading check never
        # calls this, because a built-in feature such as thread.rb is a name
        # and no path.
        File.absolute_path?(path) ? path : File.absolute_path(path)
      end

      def self.name(key)
        # Letter case is folded on every system, because a file system can
        # fold it whatever the platform's convention: the default macOS file
        # system does.
        # A byte that isn't valid UTF-8, from a file name in another encoding,
        # would make the fold raise ArgumentError in the hook, for a file that
        # no instrumented file shares a name with. Replacing it keeps two
        # names that differ only in such bytes together, which costs the hook
        # one resolution at most.
        key.rpartition("/").last.scrub.downcase(:fold)
      end

      def self.names(keys)
        keys.to_set { |key| name(key) }
      end

      def self.real(path)
        # A relative path, such as the thread.rb that Ruby lists for a
        # built-in feature, names no file of the project, and realpath would
        # resolve it against the current directory.
        File.realpath(path) if File.absolute_path?(path)
      rescue SystemCallError
        nil
      end
    end
  end
end
