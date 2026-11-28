# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "custody"
require_relative "launch_pipe"
require_relative "output_files"
require_relative "parent_pipes"
require_relative "parent_process"

module Stryker
  module Isolation
    class LaunchSite
      attr_reader :folder

      def initialize
        @runs, @results = LaunchPipe.pair
        @folder = Dir.mktmpdir("stryker-fork-")
      end

      def descriptor
        @results.writer.fileno.to_s
      end

      def redirects
        out, err = OutputFiles.new(@folder).paths("parent")
        results = @results.writer
        { :in => @runs.reader, :out => out, :err => err, results => results }
      end

      def launch(process = Process)
        Custody.new(self, process).around do |custody|
          child = yield(self, custody)
          ParentProcess.new(child, ParentPipes.new(commands: @runs.writer, results: @results.reader), @folder)
        end
      ensure
        [@runs.reader, @results.writer].each(&:close)
      end

      def remove
        [@runs.writer, @results.reader].each(&:close)
        FileUtils.remove_entry(@folder, true)
      end

      # @dynamic folder
    end
  end
end
