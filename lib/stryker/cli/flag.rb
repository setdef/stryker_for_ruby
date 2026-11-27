# frozen_string_literal: true

require_relative("../configure/origin")
require_relative("flag_text")

module Stryker
  class CLI
    class Flag < Data.define(:option, :argument, :convert, :summary)
      SHORT = { mutate: "-m", concurrency: "-c" }.freeze
      private_constant(:SHORT)

      def switch?
        convert == :switch
      end

      def long_name
        Configure::Origin.flags.spell(option)
      end

      def short_name
        SHORT[option.to_sym]
      end

      def spellings
        switch? ? [long_name, long_name.sub("--", "--no-")] : [long_name]
      end

      def register(parser, options)
        if switch?
          parser.on(long_name.sub("--", "--[no-]"), summary) { |on| options[option] = on }
        else
          parser.on(*usage) { |word| options[option] = read(word, options[option]) }
        end
      end

      def usage
        [short_name, "#{long_name} #{argument}", summary].compact
      end

      def read(word, earlier)
        return [*earlier, *FlagText.list(word)] if convert == :list

        FlagText.public_send(convert, word)
      end

      # @dynamic option, argument, convert, summary
    end
  end
end
