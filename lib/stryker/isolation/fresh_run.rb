# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "messages"
require_relative "output_files"
require_relative "verdict"

module Stryker
  module Isolation
    class FreshRun
      attr_reader :run

      def initialize(run)
        @run = run
        @folder = Dir.mktmpdir("stryker-run-")
        @outputs = OutputFiles.new(@folder)
      end

      def paths
        input = File.join(@folder, "run")
        results = File.join(@folder, "results")
        # Binary, because a text-mode write on Windows turns each LF into
        # CRLF.
        File.binwrite(input, @run.to_json)
        [input, results]
      end

      def output_options
        out, err = @outputs.paths("process")
        { in: File::NULL, out:, err: }
      end

      def result(ending)
        Verdict.new(@run, Messages.parse(results_text), ending.with(errors: @outputs.tail("process"))).result
      ensure
        remove
      end

      def remove
        FileUtils.remove_entry(@folder, true)
      end

      private def results_text
        results = File.join(@folder, "results")
        # A process that ended before it opened the file wrote nothing.
        File.exist?(results) ? File.read(results, mode: "rb", encoding: Encoding::UTF_8) : ""
      end

      # @dynamic run
    end
  end
end
