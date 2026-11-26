# frozen_string_literal: true

require_relative "heredoc"
require_relative "plain_mutant"
require_relative "removed_bodies"

module Stryker
  class Instrumenter
    module InPlace
      def self.of(node, plain, text)
        parsed = plain.result
        source = parsed.source.source
        location = node.location
        # The bodies of the node's heredocs lie below it, where text with no
        # heredoc opener, such as a joined line, would leave them as code.
        kept = PlainMutant.without(source, RemovedBodies.after(Heredoc.in(parsed.value), location))
        "#{kept.byteslice(0, location.start_offset)}#{text}#{kept.byteslice((location.end_offset)..)}"
          .force_encoding(source.encoding)
      end
    end
  end
end
