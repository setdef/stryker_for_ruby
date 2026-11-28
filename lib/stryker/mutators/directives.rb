# frozen_string_literal: true

require_relative "../file_name"
require_relative "code_lines"
require_relative "disable_comment"

module Stryker
  module Mutators
    class Directives
      UNKNOWN = "%<where>s: warning: Stryker (for Ruby) has no mutator named %<name>s, so that name turns " \
        "nothing off in this comment. The valid names are %<valid>s."
      private_constant(:UNKNOWN)

      def initialize(file:, result:, names:, warnings: $stderr)
        code = CodeLines.new(result)
        @names = names
        @warnings = warnings
        @comments = result.comments.filter_map { |comment| DisableComment.read(comment, code) }
        @comments.each { |comment| report(comment, "#{FileName.shown(file)}:#{comment.line}") }
      end

      def reason(candidate)
        # @type var none: String?
        none = nil
        @comments.reduce(none) do |earlier, comment|
          comment.decide(candidate, earlier)
        end
      end

      private def report(comment, where)
        comment.unknown(@names.map(&:downcase)).each do |name|
          @warnings.puts(format(UNKNOWN, where:, name: name.inspect, valid: @names.join(", ")))
        end
      end
    end
  end
end
