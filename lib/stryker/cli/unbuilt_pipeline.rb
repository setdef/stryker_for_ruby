# frozen_string_literal: true

require_relative("../unsupported_error")

module Stryker
  class CLI
    class UnbuiltPipeline
      MESSAGE = "A run isn't built yet: the command reads and checks the configuration, and then stops."
      public_constant(:MESSAGE)

      def call(_config, **_streams)
        raise(UnsupportedError, MESSAGE)
      end
    end
  end
end
