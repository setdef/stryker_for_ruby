# frozen_string_literal: true

require_relative "../json_reader"
require_relative "location"

class CriticFaults
  # A smell that reek or flay found, as RubyCritic's report gives it.
  #
  # +locations+:: the Locations of the smell, in the order of the report
  # +context+:: the class or method that has the smell: <tt>Foo#bar</tt>
  # +message+:: what the smell is, in the words of the tool that found it
  # +type+:: the name that the tool gives the smell: +DuplicateMethodCall+
  class Smell < Data.define(:locations, :context, :message, :type)
    # How many of a smell's places its line names. A smell in more places
    # names the first few and counts the rest.
    LOCATIONS_SHOWN = 3
    private_constant(:LOCATIONS_SHOWN)

    # Reads a smell from +object+, one item of a file's +smells+. Raises
    # CriticFaults::Malformed for a missing member, or one of another kind.
    def self.from_report(object)
      reader = JSONReader.new(object, "a smell of RubyCritic's report", Malformed)
      new(
        locations: reader.objects("locations").map { |location| Location.from_report(location) },
        context: reader.string("context"),
        message: reader.string("message"),
        type: reader.string("type")
      )
    end

    # The line for the smell: where it is, what it is, and its type.
    def fault
      places = locations.map(&:to_s)
      more = places.size - LOCATIONS_SHOWN
      where = more.positive? ? "#{places.first(LOCATIONS_SHOWN).join(', ')} and #{more} more" : places.join(", ")
      "#{where}: #{context} #{message} (#{type})"
    end

    # @dynamic locations, context, message, type
  end
end
