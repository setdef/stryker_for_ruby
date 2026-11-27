# frozen_string_literal: true

require "json"
require_relative "critic_faults/analysed_module"
require_relative "json_reader"

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
  # The text is not a RubyCritic report: it is not a JSON object, or a member
  # that the class reads is missing or of another kind.
  class Malformed < StandardError; end

  # One line for each file rated below A and for each smell, from the text of
  # a RubyCritic JSON report. Empty when there is nothing to fix. Raises
  # Malformed for text that is not a RubyCritic report.
  def self.in_report(json)
    report = JSON.parse(json)
    raise(Malformed, "RubyCritic's report is not a JSON object") unless report.is_a?(Hash)

    reader = JSONReader.new(report, "RubyCritic's report", Malformed)
    reader.objects("analysed_modules").flat_map { |object| AnalysedModule.from_report(object).faults }
  end
end
