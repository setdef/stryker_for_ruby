# frozen_string_literal: true

require_relative("../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../support/site_case")

# Checks the instrumented source for the examples in
# docs/design/mutant-placement.md, the mutants that get no switch, the
# errors, and the hits that switches record.
class InstrumenterTest < Minitest::Test
  include SiteCase

  def test_a_site_with_one_mutant_gets_a_ternary
    expected = "total = (::Stryker::Active.id == 1 ? (a - b) : (::Stryker::Active.hit(1); (a + b)))\n"

    assert_equal(expected, instrument("total = a + b\n", ["a + b", "a - b"]).source)
  end

  def test_a_site_with_several_mutants_gets_an_if_elsif_chain
    result = instrument("total = a + b\n", ["a + b", "a - b"], ["a + b", "a * b"], ["a + b", "0"])
    expected = "total = (if ::Stryker::Active.id == 1 then (a - b) elsif ::Stryker::Active.id == 2 then (a * b) " \
      "elsif ::Stryker::Active.id == 3 then (0) else (::Stryker::Active.hit(1, 2, 3); (a + b)) end)\n"

    assert_equal(expected, result.source)
  end

  def test_an_inner_switch_goes_in_the_outer_original_branch_only
    result = instrument("total = a + b * c\n", ["a + b * c", "a - b * c"], ["b * c", "b / c"])
    expected = "total = (::Stryker::Active.id == 1 ? (a - b * c) : (::Stryker::Active.hit(1); " \
      "(a + (::Stryker::Active.id == 2 ? (b / c) : (::Stryker::Active.hit(2); (b * c))))))\n"

    assert_equal(expected, result.source)
  end

  def test_no_mutants_leave_the_source_as_it_was
    source = "# frozen_string_literal: true\n\ntotal = a + b # Why.\n"

    assert_equal(source, Stryker::Instrumenter.instrument(source, []).source)
  end

  def test_everything_outside_the_switches_stays_as_it_was
    source = "# frozen_string_literal: true\n# The total.\ntotal = a + b # Why.\n__END__\na + b\n"
    result = instrument(source, ["a + b", "a - b"])

    assert_equal(
      source.sub("a + b", "(::Stryker::Active.id == 1 ? (a - b) : (::Stryker::Active.hit(1); (a + b)))"),
      result.source
    )
  end

  def test_a_multi_line_mutant_goes_on_one_line
    result = instrument("def total(a, b)\n  a + b\nend\n", %w[total sum])
    expected = "(::Stryker::Active.id == 1 ? (def sum(a, b) a.+(b); end) : (::Stryker::Active.hit(1); " \
      "(def total(a, b)\n  a + b\nend)))\n"

    assert_equal(expected, result.source)
  end

  def test_a_guard_holds_its_own_switch_inside_a_pattern
    result = instrument("case 5\nin Integer => y if y > 1\n  p y\nend\n", ["y > 1", "y > 9"])

    assert_includes(result.source, "in Integer => y if (::Stryker::Active.id == 1 ? (y > 9) :")
  end

  def test_a_pinned_expression_holds_its_own_switch_inside_a_pattern
    result = instrument("case 5\nin ^(2 + 3) then p :five\nend\n", ["2 + 3", "9"])

    assert_includes(result.source, "in ^((::Stryker::Active.id == 1 ? (9) :")
  end

  def test_the_source_keeps_its_encoding
    source = "s = 'é'\np s + 'b'\n"

    assert_equal(Encoding::UTF_8, instrument(source, ["'b'", "'c'"]).source.encoding)
  end

  def test_an_edit_after_a_multibyte_character
    assert_site("s = 'é'\np s + 'b'\n", ["'b'", "'c'"])
  end

  def test_a_switch_records_a_hit_each_time_its_original_branch_runs
    source = "def f\n  1 + 2\nend\ndef g\n  3 + 4\nend\np f\n"

    assert_equal("1", hits(instrument(source, ["1 + 2", "1 - 2"], ["3 + 4", "3 - 4"]).source))
  end

  def test_a_switch_records_no_hit_for_an_inner_site_while_its_mutant_runs
    source = "p(1 + 2 * 3)\n"
    result = instrument(source, ["1 + 2 * 3", "1 - 2 * 3"], ["2 * 3", "2 / 3"])

    assert_equal(["1 2", ""], [hits(result.source), hits(result.source, 1)])
  end

  def hits(instrumented, active = nil)
    Dir.mktmpdir do |folder|
      path = File.join(folder, "hits")
      run_ruby(folder, instrumented, active, hits: path)
      File.read(path)
    end
  end
end
