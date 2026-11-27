# frozen_string_literal: true

require "json"

module Stryker
  module JsonValue
    def self.included(base)
      base.extend(Reading)
    end

    def self.plain(value)
      case value
      when Hash, JsonValue then plain_hash(value)
      when Array then value.map { |item| plain(item) }
      when String, Symbol then clean_text(value)
      else value
      end
    end

    def self.plain_hash(value)
      value.to_h.to_h { |key, item| [clean_text(key), plain(item)] }
    end

    def self.clean_text(text)
      # JSON.generate refuses a String that isn't valid UTF-8, and a test can
      # fail with such a message, so a refusal would lose the failure.
      text.to_s.encode("UTF-8", invalid: :replace, undef: :replace).scrub
    end

    def as_json(_options = nil)
      JsonValue.plain_hash(self)
    end

    def to_json(*)
      JSON.generate(as_json)
    end

    module Reading
      AS_IT_IS = :itself.to_proc
      private_constant(:AS_IT_IS)

      def from_json(text)
        object = JSON.parse(text)
        raise(ArgumentError, "expected a JSON object, got #{object.class}") unless object.is_a?(Hash)

        from_h(object)
      end

      def from_h(object)
        new(**object.transform_keys(&:to_sym).to_h { |name, value| [name, readers.fetch(name, AS_IT_IS).call(value)] })
      end

      def readers
        {}
      end
    end
  end
end
