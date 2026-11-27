# frozen_string_literal: true

module Stryker
  class CLI
    class Streams < Data.define(:stdout, :stderr)
      # @dynamic stdout, stderr
    end
  end
end
