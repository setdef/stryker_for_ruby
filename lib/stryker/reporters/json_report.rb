# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "whole_run"

module Stryker
  module Reporters
    class JsonReport < WholeRun
      FILE_NAME = File.join("reports", "mutation", "mutation.json")
      public_constant(:FILE_NAME)

      def initialize(config:, root:)
        super
        @path = File.join(root, FILE_NAME)
      end

      private def publish(report)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.generate(report.to_h))
      end
    end
  end
end
