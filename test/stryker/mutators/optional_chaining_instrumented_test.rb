# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/optional_chaining"
require_relative("../../support/mutator_sites")

# Runs the mutants of OptionalChaining through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class OptionalChainingInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  CHAIN = <<~RUBY
    def city(customer)
      customer&.address&.city
    end
    Customer = Struct.new(:address)
    Address = Struct.new(:city)
    p city(Customer.new(Address.new("Oslo")))
    p((city(Customer.new(nil)) rescue :raised))
    p((city(nil) rescue :raised))
  RUBY
  private_constant(:CHAIN)

  def mutator
    Stryker::Mutators::OptionalChaining
  end

  def assert_sites(count, source, holder: Prism::CallNode)
    assert_equal(count, assert_mutator_site(source, mutator, holder:).size)
  end

  def test_a_call
    assert_sites(1, "o = nil\np o&.size\n")
  end

  def test_each_call_in_a_chain
    assert_sites(2, CHAIN)
  end

  def test_a_call_with_a_block
    assert_sites(1, "x = nil\np x&.size { |a| a }\n")
  end

  def test_an_attribute_assignment
    assert_sites(1, "o = nil\no&.n = 4\np o\n")
  end

  def test_an_operator_assignment
    assert_sites(1, "o = nil\no&.n += 4\np o\n", holder: Prism::CallOperatorWriteNode)
  end

  def test_an_or_assignment
    source = "def fill(o)\n  o&.n ||= 4\n  o&.n\nend\np fill(Struct.new(:n).new(nil))\np((fill(nil) rescue :raised))\n"

    assert_sites(2, source, holder: [Prism::DefNode, Prism::CallNode])
  end

  def test_a_receiver_that_is_a_literal_gets_no_mutant
    assert_sites(1, "o = nil\np [1&.succ, o&.size]\n")
  end
end
