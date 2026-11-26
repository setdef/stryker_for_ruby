# frozen_string_literal: true

module Stryker
  class Instrumenter
    # steep:ignore:start
    class PlainMutant < Data.define(:mutant, :span, :result)
      # steep:ignore:end
      def self.without(source, bodies)
        bodies.reverse.reduce(source.b) do |text, body|
          "#{text.byteslice(0, body.start_offset)}#{text.byteslice((body.end_offset)..)}".b
        end
      end

      def self.wrapped(text, span)
        start_offset = span.start_offset
        end_offset = span.end_offset
        "#{text.byteslice(0, start_offset)}(#{text.byteslice(start_offset...end_offset)})" \
          "#{text.byteslice(end_offset..)}".b
      end

      def self.growth(mutant, bodies, location)
        end_offset = location.end_offset
        edit_growth(mutant, location) - bodies.sum { |body| (body.end_offset <= end_offset) ? body.length : 0 }
      end

      def self.edit_growth(mutant, location)
        mutant.inside?(location) ? mutant.growth : 0
      end
      private_class_method(:edit_growth)
    end
  end
end
