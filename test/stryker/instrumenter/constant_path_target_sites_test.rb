# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the constant path that an assignment writes to, from the reads and
# keywords table of the placement design. It can't stand in parentheses, so
# each switch goes on the if around it.
class ConstantPathTargetSitesTest < Minitest::Test
  include SiteCase

  # +assignment+ to Shelf::Box inside an if, in a file that defines Shelf.
  def program(assignment)
    "module Shelf\n  Box = 1\nend\nif true\n  #{assignment}\nend\np Shelf.constants.sort\n"
  end

  def assert_target(assignment)
    assert_site(program(assignment), ["Shelf::Box", "Shelf::Bag"], holder: Prism::IfNode, warnings: false)
  end

  def test_an_assignment
    assert_target("Shelf::Box = 2")
  end

  def test_an_or_assignment
    assert_target("Shelf::Box ||= 2")
  end

  def test_an_and_assignment
    assert_target("Shelf::Box &&= 2")
  end

  def test_an_operator_assignment
    assert_target("Shelf::Box += 1")
  end
end
