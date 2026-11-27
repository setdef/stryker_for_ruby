# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/string_literal"
require_relative("../../support/mutator_sites")

# Runs the mutants of StringLiteral through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class StringLiteralInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::StringLiteral
  end

  def test_strings_of_each_quote
    source = "p('a')\np(\"b\")\np(?c)\np(%q(d))\n"

    assert_equal(4, assert_mutator_site(source, mutator, holder: Prism::StringNode).size)
  end

  def test_an_empty_string
    assert_equal(1, assert_mutator_site("p('')\n", mutator, holder: Prism::StringNode).size)
  end

  def test_a_string_that_is_a_receiver
    assert_equal(1, assert_mutator_site("p('a'.upcase)\n", mutator, holder: Prism::StringNode).size)
  end

  def test_a_string_that_is_a_hash_value
    source = "h = { 'a' => 'b' }\np h\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::StringNode).size)
  end

  def test_a_string_in_a_when_clause
    source = "x = 'a'\np(case x\n  when 'a' then 1\n  else 2\n  end)\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::StringNode).size)
  end

  def test_a_string_in_a_case_in_pattern
    source = "x = 'a'\np(case x\n  in 'a' then 1\n  else 2\n  end)\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: [Prism::StringNode, Prism::CaseMatchNode]).size)
  end

  def test_an_interpolated_string
    source = "t = 5\np(\"Total: \#{t}\")\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::InterpolatedStringNode).size)
  end

  def test_an_interpolated_string_with_a_string_inside_its_interpolation
    source = "t = 5\np(\"Total: \#{t} \#{'x'}\")\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::InterpolatedStringNode).size)
  end

  def test_adjacent_literals
    assert_equal(1, assert_mutator_site("p('a' \"b\")\n", mutator, holder: Prism::InterpolatedStringNode).size)
  end

  def test_adjacent_literals_joined_by_a_backslash
    source = "p('a' \\\n  'b')\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::InterpolatedStringNode).size)
  end

  def test_a_heredoc
    source = "s = <<~TEXT\n  hello\nTEXT\np s\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::StringNode).size)
  end

  def test_an_interpolated_heredoc
    source = "t = 5\ns = <<~TEXT\n  total \#{t}\nTEXT\np s\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::InterpolatedStringNode).size)
  end

  def test_a_heredoc_with_a_method_call_after_it
    source = "s = <<~TEXT.strip\n  hello\nTEXT\np s\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::StringNode).size)
  end

  def test_a_heredoc_as_an_argument_with_more_arguments_after_it
    source = "def f(s, n) = [s, n]\np f(<<~A, 2)\n  hi\nA\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::StringNode).size)
  end

  def test_two_heredocs_on_one_line
    source = "def f(a, b) = [a, b]\np f(<<~A, <<~B)\n  one\nA\n  two\nB\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::StringNode).size)
  end

  def test_a_string_under_a_frozen_string_literal_comment
    source = "# frozen_string_literal: true\ns = 'a'\np([s.frozen?, s.equal?('a'), 'b'.upcase])\n"

    assert_equal(3, assert_mutator_site(source, mutator, holder: Prism::StringNode).size)
  end
end
