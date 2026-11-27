# frozen_string_literal: true

require_relative("../source_files")
require_relative("left_out_templates")

module Stryker
  class CLI
    class Templates
      TEMPLATE = ".erb"
      LEAVE_OUT = "!**/*.erb"
      private_constant(:TEMPLATE, :LEAVE_OUT)

      def initialize(config, root)
        @config = config
        @root = root
      end

      def config(stderr)
        return @config if @config.given.include?(:mutate)

        count = templates
        return @config if count.zero?

        stderr.puts(LeftOutTemplates.new(count))
        @config.with(mutate: [*patterns, LEAVE_OUT])
      end

      private def templates
        SourceFiles.new(@root, patterns).to_a.count { |path| File.extname(path) == TEMPLATE }
      end

      private def patterns
        @config.mutate
      end
    end
  end
end
