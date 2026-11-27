# frozen_string_literal: true

require_relative "lookup_table"

module Stryker
  module Runtime
    module Cache
      INDEX = "index"
      SEPARATOR = "\0"
      NUL_IN_PATH = "A path holds a NUL byte, which no file's path can hold, so the cache can't list it."
      private_constant(:INDEX, :NUL_IN_PATH, :SEPARATOR)

      def self.write(directory, sources)
        index = index(sources.keys)
        # Binary writes, because a text-mode write on Windows turns each LF
        # into CRLF, and the instrumented source has to keep its bytes. Each
        # source goes to a file named by its place in the index, so no name
        # that the project chose becomes part of a path in the cache.
        sources.each_value.with_index { |source, place| File.binwrite(entry(directory, place), source) }
        File.binwrite(File.join(directory, INDEX), index)
        nil
      end

      def self.read(directory, separator = File::ALT_SEPARATOR)
        LookupTable.of(table(directory), separator)
      end

      def self.text(file)
        # Ruby reads a source file as UTF-8 unless a magic comment says
        # otherwise, and compile honors that comment, so the bytes are read
        # as they are and only tagged.
        File.binread(file).force_encoding(Encoding::UTF_8)
      end

      def self.index(paths)
        # The paths and nothing else, with NUL between them, because no path
        # holds a NUL. Reading it takes String#split, so reading the cache
        # needs no format library. The project process loads json anyway, for
        # the runs and messages that cross its pipes.
        raise(ArgumentError, NUL_IN_PATH) if paths.any? { |path| path.include?(SEPARATOR) }

        # Each path goes in as its bytes, because Ruby tags a path from the
        # file system with the file system's encoding and a path from the
        # configuration with UTF-8, and a join of two strings in encodings
        # that don't match, each with a letter outside ASCII, raises.
        paths.map(&:b).join(SEPARATOR)
      end

      def self.entry(directory, place)
        File.join(directory, "#{place}.rb")
      end

      def self.table(directory)
        paths = text(File.join(directory, INDEX)).split(SEPARATOR)
        paths.each_with_index.to_h { |path, place| [path, entry(directory, place)] }
      end
      private_class_method(:entry, :index, :table)
    end
  end
end
