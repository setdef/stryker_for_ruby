# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/operator_site"

# Checks what a class gets from OperatorSite: which nodes are calls written as
# operators, and the edits of a table of replacements. The class under test is
# the smallest includer, so that no mutator's rules are in the way.
class OperatorSiteTest < Minitest::Test
  class Site < Data.define(:call, :receiver, :operator_loc)
    include Stryker::Mutators::OperatorSite

    def self.written(call)
      new(call:, receiver: call.receiver, operator_loc: call.message_loc)
    end
  end
  private_constant(:Site)

  def node(source)
    Prism.parse(source).value.statements.body.first
  end

  def site(source, names)
    Site.of(node(source), names)
  end

  def test_a_call_named_by_the_list_and_written_with_no_dot_is_a_site
    assert_equal("a + b", site("a + b", [:+]).call.slice)
  end

  def test_a_prefix_operator_is_a_site
    assert_equal("!a", site("!a", [:!]).call.slice)
  end

  def test_a_call_with_another_name_is_none
    assert_nil(site("a - b", [:+]))
  end

  def test_a_call_written_with_a_dot_is_none
    assert_equal([nil, nil, nil], ["a.+(b)", "a&.+(b)", "self.+(b)"].map { |source| site(source, [:+]) })
  end

  def test_a_node_that_is_not_a_call_is_none
    assert_nil(site("a = 1", [:+]))
  end

  def test_the_operator_of_a_site_is_the_name_of_its_call
    assert_equal(:+, site("a + b", [:+]).operator)
  end

  def test_a_nil_replacement_makes_the_call_its_receivers_source
    edits = Site.edits(node("a + b"), { "+": [nil] }) { false }

    assert_equal(["a"], edits.map(&:replacement))
  end

  def test_a_site_makes_an_edit_for_each_replacement_of_the_table_in_its_order
    edits = Site.edits(node("a + b"), { "+": %w[- *] }) { false }

    assert_equal(["a - b", "a * b"], edits.map(&:replacement))
  end

  def test_a_site_makes_no_edit_when_the_block_is_true_of_it
    assert_empty(Site.edits(node("a + b"), { "+": %w[-] }) { true })
  end

  def test_a_site_makes_no_edit_of_an_operator_the_table_does_not_list
    assert_empty(Site.edits(node("a + b"), { "-": %w[+] }) { false })
  end
end
