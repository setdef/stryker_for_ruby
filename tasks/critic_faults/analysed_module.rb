# frozen_string_literal: true

require_relative "../json_reader"
require_relative "smell"

class CriticFaults
  # One file that RubyCritic analyzed, as its report gives it.
  #
  # +path+:: the file's path
  # +rating+:: the file's letter, from A to F
  # +smells+:: the Smells in the file
  class AnalysedModule < Data.define(:path, :rating, :smells)
    # The rating that the gate accepts.
    RATING = "A"
    private_constant(:RATING)

    # Reads a file from +object+, one item of the report's +analysed_modules+.
    # Raises CriticFaults::Malformed for a missing member, or one of another
    # kind.
    def self.from_report(object)
      reader = JSONReader.new(object, "a file of RubyCritic's report", Malformed)
      new(
        path: reader.string("path"),
        rating: reader.string("rating"),
        smells: reader.objects("smells").map { |smell| Smell.from_report(smell) }
      )
    end

    # The lines for the file: one for a rating below A, then one for each
    # smell.
    def faults
      lines = smells.map(&:fault)
      (rating == RATING) ? lines : ["#{path} is rated #{rating}.", *lines]
    end

    # @dynamic path, rating, smells
  end
end
