# frozen_string_literal: true

require_relative "heredoc"
require_relative "patch"
require_relative "patches"
require_relative "removed_bodies"

module Stryker
  class Instrumenter
    module InPlace
      def self.of(node, parsed, text)
        location = node.location
        # The bodies of the node's heredocs lie below it, where text with no
        # heredoc opener, such as a joined line, would leave them as code.
        bodies = RemovedBodies.after(Heredoc.in(parsed.value), location)
        Patches.apply(parsed.source.source, [*bodies.map { |body| Patch.remove(body) }, Patch.replace(location, text)])
      end
    end
  end
end
