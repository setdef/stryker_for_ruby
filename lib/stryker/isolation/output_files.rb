# frozen_string_literal: true

module Stryker
  module Isolation
    class OutputFiles
      LINES = 20
      public_constant(:LINES)

      def initialize(folder)
        @folder = folder
      end

      def paths(name)
        [File.join(@folder, "#{name}.out"), File.join(@folder, "#{name}.err")]
      end

      def tail(name)
        path = paths(name).last
        # A process that ended before it started writes no file. Bytes,
        # because a test can write anything to standard error.
        text = File.exist?(path) ? File.binread(path).force_encoding(Encoding::UTF_8).scrub : ""
        text.lines.last(LINES).join
      end
    end
  end
end
