# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "message"
require_relative "messages"
require_relative "output_files"
require_relative "verdict"

module Stryker
  module Isolation
    class FreshRun
      attr_reader :run

      def self.judged(run)
        new(run) { |messages, ending| yield(Verdict.new(run, messages, ending).result) }
      end

      def initialize(run, &landing)
        @run = run
        @landing = landing
        @folder = Dir.mktmpdir("stryker-run-")
        @outputs = OutputFiles.new(@folder)
      end

      def paths
        input = File.join(@folder, "run")
        # Binary, because a text-mode write on Windows turns each LF into
        # CRLF.
        File.binwrite(input, @run.to_json)
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

      def land(ending)
        @landing.call(Messages.parse(results_text), ending.with(errors: @outputs.tail("process")))
        nil
      ensure
        remove
      end

      def remove
        FileUtils.remove_entry(@folder, true)
      end

      private def results_path
        File.join(@folder, "results")
      end

      private def results_text
        results = results_path
        # A process that ended before it opened the file wrote nothing.
        File.exist?(results) ? File.read(results, mode: "rb", encoding: Encoding::UTF_8) : ""
      end

      # @dynamic run
    end
  end
end
