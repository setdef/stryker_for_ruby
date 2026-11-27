# frozen_string_literal: true

module Stryker
  module Mutators
    class DisableComment < Data.define(:line, :names, :reason, :lines)
      PATTERN = /\A\s?Stryker (disable|restore)(?: (next-line))? ([a-zA-Z, ]+)(?::(.+)?)?/
      DEFAULT_REASON = "Ignored using a comment"
      ALL = "all"
      NO_LINES = (0...0)
      private_constant(:PATTERN, :DEFAULT_REASON, :ALL, :NO_LINES)

      def self.read(comment, code)
        location = comment.location
        parse(location.slice.scrub.delete_prefix("#"), location.start_line, code)
      end

      def self.parse(text, line, code)
        match = PATTERN.match(text)
        match && from(match, line, code)
      end

      def self.from(match, line, code)
        kind, scope, names, given = match.captures
        new(
          line:,
          names: names.to_s.split(",", -1).map(&:strip).to_h { |name| [name.downcase, name] },
          reason: (given_or_default(given) if kind == "disable"),
          lines: scope ? only(code.after(line)) : (line..)
        )
      end

      def self.given_or_default(given)
        text = given.to_s.strip
        text.empty? ? DEFAULT_REASON : text
      end

      def self.only(line)
        line ? (line..line) : NO_LINES
      end

      def covers?(candidate)
        lines.cover?(candidate.line) && (names.key?(candidate.mutator_name.downcase) || names.key?(ALL))
      end

      def decide(candidate, earlier)
        covers?(candidate) ? reason : earlier
      end

      def unknown(valid)
        names.except(*valid, ALL).values
      end

      # @dynamic line, names, reason, lines
    end
  end
end
