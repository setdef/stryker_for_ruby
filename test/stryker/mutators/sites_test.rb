# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/sites"

# Checks the sites that the tree, and not one mutator, leaves out: the
# arguments of a call that loads code, and a Sorbet signature.
class SitesTest < Minitest::Test
  def children(source)
    node = Prism.parse(source).value.statements.body.first
    Stryker::Mutators::Sites.children(node).map(&:slice)
  end

  def test_a_call_gives_all_its_children
    assert_equal(%w[a b], children("a.m(b)"))
  end

  def test_a_node_that_is_not_a_call_gives_all_its_children
    assert_equal(["1"], children("total = 1"))
  end

  def test_the_arguments_of_require_are_left_out
    assert_empty(children("require 'json'"))
  end

  def test_the_arguments_of_require_relative_are_left_out
    assert_empty(children("require_relative \"a\#{b}\""))
  end

  def test_the_arguments_of_load_are_left_out
    assert_empty(children("load(path + 'x')"))
  end

  def test_the_arguments_of_autoload_are_left_out
    assert_empty(children("autoload :Json, 'json'"))
  end

  def test_the_arguments_of_autoload_on_a_module_are_left_out_and_its_receiver_is_kept
    assert_equal(["Billing"], children("Billing.autoload(:Json, 'json')"))
  end

  def test_require_with_a_receiver_keeps_its_arguments
    assert_equal(["loader", "'json'"], children("loader.require('json')"))
  end

  def test_load_with_a_receiver_keeps_its_arguments
    assert_equal(["loader", "'json'"], children("loader.load('json')"))
  end

  def test_a_method_that_only_starts_like_a_loader_keeps_its_arguments
    assert_equal(["'json'"], children("require_all('json')"))
  end

  def test_a_loader_keeps_its_block
    assert_equal(["{ nil }"], children("require { nil }"))
  end

  def test_require_with_no_arguments_has_no_children
    assert_empty(children("require"))
  end

  def test_a_type_signature_has_no_children
    assert_empty(children("sig { params(rate: Float).returns(Float) }"))
  end

  def test_sig_with_a_receiver_keeps_its_children
    assert_equal(["T", "{ nil }"], children("T.sig { nil }"))
  end

  def test_sig_with_no_block_keeps_its_arguments
    assert_equal(["name"], children("sig(name)"))
  end

  def test_sig_with_a_block_argument_keeps_its_arguments
    assert_equal(["&block"], children("sig(&block)"))
  end
end
