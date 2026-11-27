# frozen_string_literal: true

module Stryker
  module Reporters
    module CodeUnits
      PICTOGRAPH = /(?:\p{Emoji_Presentation}|\p{Extended_Pictographic}\u{FE0F})[\u{1F3FB}-\u{1F3FF}]?/
      SUBDIVISION_FLAG = /
        \u{1F3F4}\u{E0067}\u{E0062}
        (?:\u{E0065}\u{E006E}\u{E0067}|\u{E0073}\u{E0063}\u{E0074}|\u{E0077}\u{E006C}\u{E0073})
        \u{E007F}
      /x
      EMOJI = Regexp.union(
        SUBDIVISION_FLAG,
        /\p{Regional_Indicator}{2}/,
        /#{PICTOGRAPH}(?:\u{200D}#{PICTOGRAPH})*/,
        /[0-9#*]\u{FE0F}\u{20E3}/
      )
      private_constant(:PICTOGRAPH, :SUBDIVISION_FLAG, :EMOJI)

      def self.head(text, count)
        decoded(text.encode(Encoding::UTF_16LE).byteslice(0, count * 2))
      end

      def self.tail(text, count)
        decoded(text.encode(Encoding::UTF_16LE).byteslice((count * 2)..))
      end

      def self.width(text)
        # SPDX-SnippetBegin
        # SPDX-License-Identifier: Apache-2.0
        # SPDX-SnippetCopyrightText: Stryker Mutator contributors
        # SPDX-SnippetComment: Ported from stringWidth in packages/core/src/utils/string-utils.ts of
        # StrykerJS. The port finds an emoji with Ruby's Unicode properties and the subdivision flags that
        # emoji-regex matches, where the original uses the emoji-regex package.
        text.gsub(EMOJI, "  ").encode(Encoding::UTF_16LE).bytesize / 2
        # SPDX-SnippetEnd
      end

      def self.decoded(bytes)
        String(bytes).force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8)
      end
      private_class_method(:decoded)
    end
  end
end
