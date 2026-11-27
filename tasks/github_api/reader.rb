# frozen_string_literal: true

class GitHubAPI
  # Reads the members of one object of GitHub's API as the kind each is
  # documented to have, so that a member that is missing or of another kind
  # raises where it is read, and no nil travels on from there.
  class Reader
    # +object+ is what GitHub's API answered, and +what+ says which, in the
    # message of an error: "a run".
    def initialize(object, what)
      @object = object
      @what = what
    end

    # The String at +key+. Raises GitHubAPI::Error when +key+ is missing or
    # holds another kind.
    def string(key)
      value = value(key)
      return value if value.is_a?(String)

      refuse(key, value, "a String")
    end

    # The String at +key+, or nil when GitHub gives null. Raises
    # GitHubAPI::Error when +key+ is missing or holds another kind.
    def string_or_nil(key)
      value = value(key)
      return value if value.nil? || value.is_a?(String)

      refuse(key, value, "a String or null")
    end

    # The String at +key+, or nil when GitHub gives null or no +key+ at all.
    # Raises GitHubAPI::Error when +key+ holds another kind.
    def optional_string(key)
      string_or_nil(key) if @object.key?(key)
    end

    # The Integer at +key+. Raises GitHubAPI::Error when +key+ is missing or
    # holds another kind.
    def integer(key)
      value = value(key)
      return value if value.is_a?(Integer)

      refuse(key, value, "an Integer")
    end

    # The objects in the Array at +key+. Raises GitHubAPI::Error when +key+ is
    # missing, holds another kind, or holds an item that is not an object.
    def objects(key)
      items = value(key)
      refuse(key, items, "an Array") unless items.is_a?(Array)
      items.map { |item| item.is_a?(Hash) ? item : refuse(key, item, "an Array of objects") }
    end

    private def value(key)
      @object.fetch(key) { raise(Error, "GitHub's API answered #{@what} with no #{key.inspect}") }
    end

    private def refuse(key, value, expected)
      raise(Error, "GitHub's API answered #{@what} with #{key.inspect} as #{value.inspect}, not #{expected}")
    end
  end
end
