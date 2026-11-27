# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/edit"
require "stryker/mutators/walk"
require_relative("../../support/fake_mutator")

# Checks that a walk asks each mutator at every node, gives the mutants the
# order of the catalog's table, and passes on the file and the first ID.
class WalkTest < Minitest::Test
  # A mutator that replaces each integer literal with +to+.
  def integers(name, to)
    FakeMutator.new(name) do |node, _ancestors|
      node.is_a?(Prism::IntegerNode) ? [Stryker::Edit.over(node.location, to)] : []
    end
  end

  def walk(source, *mutators, **)
    Stryker::Mutators::Walk.new(file: "lib/a.rb", result: Prism.parse(source), mutators:, **).mutants
  end

  def summary(mutants)
    mutants.map { |mutant| [mutant.id, mutant.mutator_name, mutant.start_offset, mutant.replacement] }
  end

  def test_makes_a_mutant_of_each_edit_with_the_file_and_the_name_of_its_mutator
    expected = Stryker::Mutant.new(
      id: 1, file: "lib/a.rb", mutator_name: "Nines", start_offset: 4, end_offset: 5, replacement: "9"
    )

    assert_equal([expected], walk("x = 1\n", integers("Nines", "9")))
  end

  def test_gives_a_mutant_the_description_of_its_edit
    described = FakeMutator.new("Described") do |node, _ancestors|
      node.is_a?(Prism::IntegerNode) ? [Stryker::Edit.over(node.location, "9", "One became nine.")] : []
    end

    assert_equal(["One became nine."], walk("x = 1\n", described).map(&:description))
  end

  def test_makes_no_mutant_where_no_mutator_has_an_edit
    assert_empty(walk("x = a\n", integers("Nines", "9")))
  end

  def test_has_no_mutant_with_no_mutators
    assert_empty(walk("x = 1\n"))
  end

  def test_counts_the_ids_up_from_the_first_id
    assert_equal([8, 9], walk("x = [1, 2]\n", integers("Nines", "9"), first_id: 8).map(&:id))
  end

  def test_puts_each_mutators_mutants_together_in_the_order_of_the_list
    mutants = walk("x = [1, 2]\n", integers("Nines", "9"), integers("Zeros", "0"))
    expected = [[1, "Nines", 5, "9"], [2, "Nines", 8, "9"], [3, "Zeros", 5, "0"], [4, "Zeros", 8, "0"]]

    assert_equal(expected, summary(mutants))
  end

  def test_puts_a_mutators_mutants_in_the_order_its_sites_start
    # The tree lists an if's condition before its body, though the body starts first.
    mutants = walk("x = [1, 2] if 3\n", integers("Nines", "9"))

    assert_equal([5, 8, 14], mutants.map(&:start_offset))
  end

  def test_puts_the_edits_of_one_site_in_the_order_the_mutator_gives_them
    both = FakeMutator.new("Both") do |node, _ancestors|
      node.is_a?(Prism::IntegerNode) ? %w[9 8].map { |to| Stryker::Edit.over(node.location, to) } : []
    end

    assert_equal(%w[9 8], walk("x = 1\n", both).map(&:replacement))
  end

  def test_puts_the_outer_site_first_where_two_sites_start_together
    both = FakeMutator.new("Both") do |node, _ancestors|
      [Prism::ArrayNode, Prism::IntegerNode].include?(node.class) ? [Stryker::Edit.over(node.location, "9")] : []
    end

    assert_equal([[1, "Both", 4, "9"], [2, "Both", 5, "9"]], summary(walk("x = [1]\n", both)))
  end

  def test_orders_by_the_start_of_the_site_and_not_of_the_edit
    # The edit of the unless covers only its keyword, which starts after the
    # 1 inside it, though the unless starts first.
    mixed = FakeMutator.new("Mixed") do |node, _ancestors|
      case node
      when Prism::UnlessNode then [Stryker::Edit.over(node.keyword_loc, "if")]
      when Prism::IntegerNode then [Stryker::Edit.over(node.location, "9")]
      else []
      end
    end

    assert_equal([[1, "Mixed", 5, "if"], [2, "Mixed", 2, "9"]], summary(walk("p(1) unless c\n", mixed)))
  end

  def test_gives_each_mutator_the_ancestors_of_the_node
    seen = []
    recorder = FakeMutator.new("Recorder") do |node, ancestors|
      seen << ancestors.map(&:class) if node.is_a?(Prism::IntegerNode)
      []
    end
    walk("[1]\n", recorder)

    assert_equal([[Prism::ProgramNode, Prism::StatementsNode, Prism::ArrayNode]], seen)
  end

  def test_leaves_out_the_sites_of_a_traversal
    assert_empty(walk("require 'json'\nsig { 1 }\n", integers("Nines", "9")))
  end

  def test_leaves_out_a_mutant_that_gives_the_original_file
    assert_empty(walk("x = 1\n", integers("Ones", "1")))
  end

  def test_leaves_out_the_mutant_of_a_later_mutator_that_gives_the_same_file
    assert_equal([[1, "First", 4, "9"]], summary(walk("x = 1\n", integers("First", "9"), integers("Second", "9"))))
  end

  def test_numbers_the_mutants_of_the_default_mutators_in_the_order_of_the_catalogs_table
    result = Prism.parse("!c\nx = a + b\n")
    mutants = Stryker::Mutators::Walk.new(file: "lib/a.rb", result:).mutants

    assert_equal(%w[ArithmeticOperator BooleanLiteral], mutants.map(&:mutator_name))
    assert_equal([1, 2], mutants.map(&:id))
  end

  def test_refuses_a_file_that_does_not_parse
    error = assert_raises(ArgumentError) { walk("x = (\n") }

    assert_equal("lib/a.rb doesn't parse, so it has no sites", error.message)
  end
end
