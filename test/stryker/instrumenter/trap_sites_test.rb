# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the traps at sites that hold a switch, from the list in
# docs/design/mutant-placement.md. In each, the switch and the plain mutant
# don't run alike, which the design accepts.
class TrapSitesTest < Minitest::Test
  include SiteCase

  def test_a_local_declared_under_a_switch_stays_declared_when_its_statement_is_removed
    source = "x = 1\np x\n"
    mutant = site_mutant(source, 1, "x = 1", "nil")
    instrumented = Stryker::Instrumenter.instrument(source, [mutant]).source
    plain, switched = Dir.mktmpdir do |folder|
      [run_ruby(folder, plain_mutant(source, mutant)), run_ruby(folder, instrumented, mutant.id)]
    end
    output, errors, status = plain

    assert_equal(["", 1], [output, status], "The plain mutant raises, since x isn't declared.")
    assert_match(/undefined local variable or method 'x'/, errors)
    assert_equal(["nil\n", "", 0], switched, "The switch declares x, as nil.")
  end
end
