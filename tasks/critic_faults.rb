# frozen_string_literal: true

require "json"

# Finds what RubyCritic's JSON report holds that the gate refuses.
#
# RubyCritic fails the run on a low score, with +--minimum-score+, but it has
# no option to fail on one file's rating or on a smell. Its smells come from
# reek (code smells) and flay (duplication). This class reads the report and
# names each file below an A, and each smell in any file.
#
# === Examples
#
#   CriticFaults.in_report(File.read("tmp/rubycritic/report.json"))
#   # => ["lib/proof/a.rb is rated C.", "lib/proof/a.rb:4: Foo#bar calls 'x.y' 2 times (DuplicateMethodCall)"]
class CriticFaults
  RATING = "A"
  LOCATIONS_SHOWN = 3
  private_constant(:LOCATIONS_SHOWN, :RATING)

  # One line for each file rated below A and for each smell, from the text of
  # a RubyCritic JSON report. Empty when there is nothing to fix.
  def self.in_report(json)
    JSON.parse(json, symbolize_names: true)[:analysed_modules].flat_map { |mod| in_module(mod) }
  end

  # The lines for one analyzed file.
  def self.in_module(mod)
    path = mod[:path]
    rating = mod[:rating]
    lines = mod[:smells].map { |smell| smell_line(smell) }
    (rating == RATING) ? lines : ["#{path} is rated #{rating}.", *lines]
  end
  private_class_method(:in_module)

  # The line for one smell: where it is, what it is, and its type. A smell in
  # more than LOCATIONS_SHOWN places names the first few and counts the rest.
  def self.smell_line(smell)
    places = smell[:locations].map { |location| "#{location[:path]}:#{location[:line]}" }
    more = places.size - LOCATIONS_SHOWN
    where = more.positive? ? "#{places.first(LOCATIONS_SHOWN).join(', ')} and #{more} more" : places.join(", ")
    "#{where}: #{smell[:context]} #{smell[:message]} (#{smell[:type]})"
  end
  private_class_method(:smell_line)
end
