# frozen_string_literal: true

require_relative "../json_reader"

class CriticFaults
  # A place in a file that a smell is in, as RubyCritic's report gives it.
  #
  # +path+:: the file's path
  # +line+:: the line, from 1
  class Location < Data.define(:path, :line)
    # Reads a place from +object+, one item of a smell's +locations+. Raises
    # CriticFaults::Malformed for a missing member, or one of another kind.
    def self.from_report(object)
      reader = JSONReader.new(object, "a place of a smell of RubyCritic's report", Malformed)
      new(path: reader.string("path"), line: reader.integer("line"))
    end

    # The place as a line of the gate's output: <tt>lib/a.rb:4</tt>.
    def to_s
      "#{path}:#{line}"
    end

    # @dynamic path, line
  end
end
