# frozen_string_literal: true

require "json"
require_relative "json_value/bytes"
require_relative "json_value/reading"

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
      members(value).to_h { |key, item| [clean_text(key), plain(item)] }
    end

    def self.members(value)
      case value
      when JsonValue then value.json_members
      else value
      end
    end

    def self.clean_text(text)
      # JSON.generate refuses a String that isn't valid UTF-8, and a test can
      # fail with such a message, so a refusal would lose the failure.
      text.to_s.encode("UTF-8", invalid: :replace, undef: :replace).scrub
    end

    def as_json(_options = nil)
      JsonValue.plain_hash(self)
    end

    def json_members
      # steep:ignore:start
      exact = self.class.byte_members
      # steep:ignore:end
      to_h.to_h { |name, item| [name, exact.include?(name) ? Bytes.write(item) : item] }
    end

    def to_json(*)
      JSON.generate(as_json)
    end
  end
end
