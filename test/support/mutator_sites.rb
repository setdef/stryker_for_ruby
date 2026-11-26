# frozen_string_literal: true

require_relative("../test_helper")
require_relative("site_case")
require "stryker/mutators/walk"

# Runs a mutator's real mutants through the instrumenter, as ADR 0001's
# Confirmation asks of every kind of site: the instrumented file with no
# mutant active must print what the original prints, and with each mutant
# active, what the plain mutant prints. The test class includes SiteCase too,
# for the programs it runs.
module MutatorSites
  # Checks +source+ with every mutant that +mutator+ makes of it, and returns
  # the mutants. The switch of each must wrap a node of the class +holder+. The
  # program must print something different for each mutant, so that no mutant
  # passes by changing nothing.
  def assert_mutator_site(source, mutator, holder:)
    mutants = Stryker::Mutators::Walk.new(file: "case.rb", result: Prism.parse(source), mutators: [mutator]).mutants
    result = Stryker::Instrumenter.instrument(source, mutants)

    assert_empty(result.skipped)
    assert_equal(source.count("\n"), result.source.count("\n"), "The instrumented source has other lines.")
    mutants.each { |mutant| assert_switch_wraps(holder, result.source, mutant) }
    assert_runs_like_its_mutants(source, result.source, mutants, holder:)
    mutants
  end
end
