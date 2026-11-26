# frozen_string_literal: true

require_relative "path_key"

module Stryker
  module Runtime
    class Cache < Data.define(:files, :separator)
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
        paths = text(File.join(directory, INDEX)).split(SEPARATOR)
        pairs = paths.each_with_index.flat_map { |path, place| keyed(path, entry(directory, place), separator) }
        Ractor.make_shareable(new(files: pairs.to_h, separator:))
      end

      def self.text(file)
        # Ruby reads a source file as UTF-8 unless a magic comment says
        # otherwise, and compile honors that comment, so the bytes are read
        # as they are and only tagged.
        File.binread(file).force_encoding(Encoding::UTF_8)
      end

      def file(path)
        files[PathKey.of(path, separator)]
      end

      def self.index(paths)
        # The paths and nothing else, with NUL between them, because no path
        # holds a NUL. Reading it takes String#split, so the runtime loads no
        # format library, such as the json default gem, into a process whose
        # bundle the project controls.
        raise(ArgumentError, NUL_IN_PATH) if paths.any? { |path| path.include?(SEPARATOR) }

        paths.join(SEPARATOR)
      end

      def self.keyed(path, file, separator)
        # Under both its paths, because one process gives the hook the real
        # path for a file it finds through $LOAD_PATH or require_relative,
        # and the path as written for an absolute require.
        PathKey.of_file(path, separator).map { |key| [key, file] }
      end

      def self.entry(directory, place)
        File.join(directory, "#{place}.rb")
      end
      private_class_method(:entry, :index, :keyed)

      # @dynamic files, separator
    end
  end
end
