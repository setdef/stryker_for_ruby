# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the traps at sites that hold a switch, from the list in
# docs/design/mutant-placement.md. In each, the switch and the plain mutant
# don't run alike, which the design accepts.
class TrapSitesTest < Minitest::Test
  include SiteCase

  REGEXP_CONDITION = "$_ = 'foo'\np :y if /foo/\n"
  private_constant(:REGEXP_CONDITION)

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

  def test_a_regexp_literal_in_a_condition_prints_what_its_mutant_prints
    instrumented = Stryker::Instrumenter.instrument(REGEXP_CONDITION, [regexp_mutant]).source

    assert_instance_of(Prism::IfNode, switched_node(instrumented, 1))
    Dir.mktmpdir do |folder|
      assert_equal(printed(folder, REGEXP_CONDITION), printed(folder, instrumented), "With no mutant active.")
      assert_equal(printed(folder, plain_mutant(REGEXP_CONDITION, regexp_mutant)), printed(folder, instrumented, 1))
    end
  end

  def test_a_regexp_literal_in_a_condition_warns_once_for_each_branch
    instrumented = Stryker::Instrumenter.instrument(REGEXP_CONDITION, [regexp_mutant]).source
    warnings = Dir.mktmpdir { |folder| [REGEXP_CONDITION, instrumented].map { |program| run_ruby(folder, program)[1] } }

    assert_equal([1, 2], warnings.map { |errors| errors.scan("warning: regex literal in condition").size })
  end

  def regexp_mutant
    site_mutant(REGEXP_CONDITION, 1, "/foo/", "/bar/")
  end

  # What +program+ prints, and its exit status, without what it writes to
  # standard error.
  def printed(folder, program, active = nil)
    run_ruby(folder, program, active).values_at(0, 2)
  end
end
