# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "../events"
require_relative "../file_name"
require_relative "../unsupported_error"
require_relative "whole_run"

module Stryker
  module Reporters
    class JsonReport < WholeRun
      FILE_NAME = File.join("reports", "mutation", "mutation.json")
      NOT_UTF8 = "The json reporter can't write the test file %<name>s, because JSON holds only UTF-8 text and " \
        "the file's name isn't. Rename the file, or take json out of reporters."
      public_constant(:FILE_NAME)
      private_constant(:NOT_UTF8)

      def initialize(config:, root:)
        super
        @path = File.join(root, FILE_NAME)
      end

      def call(event)
        refuse_unreportable(event.result.results) if event.is_a?(Events::DryRunCompleted)
        super
      end

      private def refuse_unreportable(results)
        files = results.filter_map { |result| result.test.file }
        name = files.find { |file| !FileName.utf8?(file) }
        raise(UnsupportedError, format(NOT_UTF8, name: name.inspect)) if name
      end

      private def publish(report)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.generate(report.to_h))
      end
    end
  end
end
