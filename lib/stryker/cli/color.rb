# frozen_string_literal: true

module Stryker
  class CLI
    class Color
      def self.from(env, no_color_flag)
        new([no_color_flag, !env.fetch("NO_COLOR", "").empty?, env["TERM"] == "dumb"].any?)
      end

      def initialize(off)
        @off = off
      end

      def enabled_for?(stream)
        !@off && stream.tty?
      end
    end
  end
end
