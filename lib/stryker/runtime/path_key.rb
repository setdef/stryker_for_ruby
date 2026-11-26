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

      def self.real(path)
        File.realpath(path)
      rescue SystemCallError
        nil
      end
    end
  end
end
