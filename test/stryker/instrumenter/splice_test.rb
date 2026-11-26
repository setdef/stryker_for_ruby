# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter"

# Checks the order in which the splice puts the openings and closings of
# switches that meet at one offset.
class SpliceTest < Minitest::Test
  def site(start_offset, end_offset, id)
    branches = [Stryker::Instrumenter::Branch.new(id:, text: "m#{id}")]
    Stryker::Instrumenter::Site.new(start_offset:, end_offset:, branches:)
  end

  def switch(id, original)
    "(::Stryker::Active.id == #{id} ? (m#{id}) : (::Stryker::Active.hit(#{id}); (#{original})))"
  end

  def test_a_switch_that_ends_closes_before_one_that_starts_there_opens
    output = Stryker::Instrumenter::Splice.new("ab", [site(1, 2, 2), site(0, 1, 1)]).output

    assert_equal("#{switch(1, 'a')}#{switch(2, 'b')}", output)
  end

  def test_of_two_switches_that_start_together_the_outer_one_opens_first
    output = Stryker::Instrumenter::Splice.new("ab", [site(0, 1, 2), site(0, 2, 1)]).output

    assert_equal(switch(1, "#{switch(2, 'a')}b"), output)
  end

  def test_of_two_switches_that_end_together_the_inner_one_closes_first
    output = Stryker::Instrumenter::Splice.new("ab", [site(0, 2, 1), site(1, 2, 2)]).output

    assert_equal(switch(1, "a#{switch(2, 'b')}"), output)
  end

  def test_of_two_switches_with_different_closings_that_end_together_the_inner_one_closes_first
    branches = [1, 3].map { |id| Stryker::Instrumenter::Branch.new(id:, text: "m#{id}") }
    outer = Stryker::Instrumenter::Site.new(start_offset: 0, end_offset: 2, branches:)
    output = Stryker::Instrumenter::Splice.new("ab", [outer, site(1, 2, 2)]).output
    expected = "(if ::Stryker::Active.id == 1 then (m1) elsif ::Stryker::Active.id == 3 then (m3) " \
      "else (::Stryker::Active.hit(1, 3); (a#{switch(2, 'b')})) end)"

    assert_equal(expected, output)
  end

  def test_sites_at_one_node_share_a_switch_in_the_order_of_their_ids
    output = Stryker::Instrumenter::Splice.new("a", [site(0, 1, 2), site(0, 1, 1)]).output
    expected = "(if ::Stryker::Active.id == 1 then (m1) elsif ::Stryker::Active.id == 2 then (m2) " \
      "else (::Stryker::Active.hit(1, 2); (a)) end)"

    assert_equal(expected, output)
  end
end
