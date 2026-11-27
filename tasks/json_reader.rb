# frozen_string_literal: true

# Reads the members of one object that JSON.parse gave, as the kind each is
# documented to have, so that a member that is missing or of another kind
# raises where it is read, and no nil travels on from there. GitHubAPI reads
# the answers of GitHub's API with it, and CriticFaults reads RubyCritic's
# report.
#
# === Examples
#
#   reader = JSONReader.new(JSON.parse('{"id": 7}'), "GitHub's API answered a run", GitHubAPI::Error)
#   reader.integer("id") # => 7
#   reader.string("event")
#   # raises GitHubAPI::Error: GitHub's API answered a run with no "event"
class JSONReader
  # +object+ is what JSON.parse gave. +subject+ says what the object is, as the
  # start of the message of an error: "GitHub's API answered a run". +error+ is
  # the class of the error that a member that is missing or of another kind
  # raises.
  def initialize(object, subject, error)
    @object = object
    @subject = subject
    @error = error
  end

  # The String at +key+. Raises the error when +key+ is missing or holds
  # another kind.
  def string(key)
    value = value(key)
    return value if value.is_a?(String)

    refuse(key, value, "a String")
  end

  # The String at +key+, or nil when the object has null there. Raises the
  # error when +key+ is missing or holds another kind.
  def string_or_nil(key)
    value = value(key)
    return value if value.nil? || value.is_a?(String)

    refuse(key, value, "a String or null")
  end

  # The String at +key+, or nil when the object has null there or no +key+ at
  # all. Raises the error when +key+ holds another kind.
  def optional_string(key)
    string_or_nil(key) if @object.key?(key)
  end

  # The Integer at +key+. Raises the error when +key+ is missing or holds
  # another kind.
  def integer(key)
    value = value(key)
    return value if value.is_a?(Integer)

    refuse(key, value, "an Integer")
  end

  # The objects in the Array at +key+. Raises the error when +key+ is missing,
  # holds another kind, or holds an item that is not an object.
  def objects(key)
    items = value(key)
    refuse(key, items, "an Array") unless items.is_a?(Array)
    items.map { |item| item.is_a?(Hash) ? item : refuse(key, item, "an Array of objects") }
  end

  private def value(key)
    @object.fetch(key) { raise(@error, "#{@subject} with no #{key.inspect}") }
  end

  private def refuse(key, value, expected)
    raise(@error, "#{@subject} with #{key.inspect} as #{value.inspect}, not #{expected}")
  end
end
