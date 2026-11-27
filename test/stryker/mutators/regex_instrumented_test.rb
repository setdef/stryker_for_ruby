# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/regex"
require_relative("../../support/mutator_sites")

# Runs the mutants of Regex through the instrumenter and checks that the
# program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class RegexInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::Regex
  end

  def assert_sites(count, source, holder: Prism::RegularExpressionNode)
    assert_equal(count, assert_mutator_site(source, mutator, holder:).size)
  end

  def test_a_regexp_literal
    assert_sites(6, "p(['12', 'a12', '12a', \"1\\n2\", \"x\\n12\\nx\"].map { |s| s.match?(/^\\d+$/) })\n")
  end

  def test_a_regexp_literal_with_flags
    assert_sites(2, "p(['A', 'bA', \"b\\nA\"].map { |s| s.match?(/^a/i) })\n")
  end

  def test_a_regexp_literal_with_other_delimiters
    assert_sites(4, "p(['a/b', 'xa/b', 'a/bx', \"x\\na/b\", \"a/b\\nx\"].map { |s| s.match?(%r{^a/b$}) })\n")
  end

  def test_a_regexp_literal_that_declares_a_local_by_a_named_capture
    source = "['a', 'ba', \"b\\na\"].each { |s| p(/(?<x>^a)/ =~ s) }\n"

    assert_sites(2, source, holder: Prism::MatchWriteNode)
  end

  def test_a_pattern_given_to_regexp_new
    assert_sites(4, "p(['a', 'ba', \"a\\nb\", \"b\\na\", 'ab'].map { |s| s.match?(Regexp.new('^a$')) })\n", holder: Prism::StringNode)
  end

  def test_a_pattern_with_a_quantifier_and_a_group
    assert_sites(3, "p(['ab', 'abab', 'xab', 'abx'].map { |s| s.match?(/\\A(ab)+\\z/) })\n")
  end
end
