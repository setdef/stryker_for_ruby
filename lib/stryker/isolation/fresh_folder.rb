# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "message"
require_relative "messages"
require_relative "output_files"

module Stryker
  module Isolation
    class FreshFolder
      def self.made
        new(Dir.mktmpdir("stryker-run-"))
      end

      def initialize(path)
        @path = path
        @outputs = OutputFiles.new(path)
      end

      def paths(run)
        input = File.join(@path, "run")
        # Binary, because a text-mode write on Windows turns each LF into
        # CRLF.
        File.binwrite(input, run.to_json)
        [input, results_path]
      end

      def output_options
        out, err = @outputs.paths("process")
        { in: File::NULL, out:, err: }
      end

      def started?
        # The first line the process writes is its first test's start, so
        # that line is all this reads.
        first = File.open(results_path, "rb", &:gets) if File.exist?(results_path)
        first ? Message.started?(first) : false
      end

      def messages
        Messages.parse(results_text)
      end

      def errors
        @outputs.tail("process")
      end

      def remove
        FileUtils.remove_entry(@path, true)
      end

      private def results_path
        File.join(@path, "results")
      end

      private def results_text
        results = results_path
        # A process that ended before it opened the file wrote nothing.
        File.exist?(results) ? File.read(results, mode: "rb", encoding: Encoding::UTF_8) : ""
      end
    end
  end
end
