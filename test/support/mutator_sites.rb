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
  # the mutants. The switch of each must wrap a node of the class +holder+, or,
  # with an array of classes, of the class at the place of the mutant, in the
  # order of the mutants. The program must print something different for each
  # mutant, so that no mutant passes by changing nothing.
  def assert_mutator_site(source, mutator, holder:)
    mutants = Stryker::Mutators::Walk.new(file: "case.rb", result: Prism.parse(source), mutators: [mutator]).mutants
    holders = holder.is_a?(Array) ? holder : [holder] * mutants.size

    assert_instrumented(source, Stryker::Instrumenter.instrument(source, mutants), mutants.zip(holders))
    mutants
  end

  def assert_instrumented(source, result, mutants_and_holders)
    assert_empty(result.skipped)
    assert_equal(source.count("\n"), result.source.count("\n"), "The instrumented source has other lines.")
    mutants_and_holders.each { |mutant, holder| assert_switch_wraps(holder, result.source, mutant) }
    mutants_and_holders.group_by(&:last).each do |holder, group|
      assert_runs_like_its_mutants(source, result.source, group.map(&:first), holder:)
    end
  end
end
