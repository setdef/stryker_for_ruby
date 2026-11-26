# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks self as the receiver of a call, from the reads and keywords table of
# the placement design. Ruby calls a private method through a receiver only
# when the receiver is the keyword self, so the switch goes on an enclosing
# node. Each statement calls the private methods of C through self.
class SelfReceiverSitesTest < Minitest::Test
  include SiteCase

  # A class whose accessors are private, with +statement+ in the method go.
  def program(statement)
    <<~RUBY
      class C
        def initialize
          @x = 1
          @h = { k: 1 }
        end

        def go
          #{statement}
          [@x, @h]
        end

        private

        attr_accessor :x

        def [](key)
          @h[key]
        end

        def []=(key, value)
          @h[key] = value
        end
      end
      p((C.new.go rescue :private))
    RUBY
  end

  def assert_self_receiver(statement, holder)
    assert_site(program(statement), ["self", "C.new"], holder:)
  end

  def test_a_call
    assert_self_receiver("self.x = 2", Prism::CallNode)
  end

  def test_an_and_assignment_to_a_call
    assert_self_receiver("self.x &&= 2", Prism::DefNode)
  end

  def test_an_operator_assignment_to_a_call
    assert_self_receiver("self.x += 1", Prism::CallOperatorWriteNode)
  end

  def test_an_or_assignment_to_a_call
    assert_self_receiver("self.x ||= 2", Prism::DefNode)
  end

  def test_a_call_in_a_multiple_assignment
    assert_self_receiver("self.x, y = 2, 3", Prism::MultiWriteNode)
  end

  def test_an_and_assignment_to_an_index
    assert_self_receiver("self[:k] &&= 2", Prism::DefNode)
  end

  def test_an_operator_assignment_to_an_index
    assert_self_receiver("self[:k] += 1", Prism::DefNode)
  end

  def test_an_or_assignment_to_an_index
    assert_self_receiver("self[:k] ||= 2", Prism::IndexOrWriteNode)
  end

  def test_an_index_in_a_multiple_assignment
    # Ruby 3.3 calls a private []= through self in a multiple assignment,
    # and later versions raise there as well, so the mutant changes what the
    # program prints only on Ruby 3.3.
    source = program("self[:k], y = 2, 3")
    mutant = site_mutant(source, 1, "self", "C.new")
    instrumented = Stryker::Instrumenter.instrument(source, [mutant]).source

    assert_switch_wraps(Prism::MultiWriteNode, instrumented, mutant)
    Dir.mktmpdir do |folder|
      assert_equal(run_ruby(folder, source), run_ruby(folder, instrumented), "With no mutant active.")
      plain = run_ruby(folder, plain_mutant(source, mutant))

      assert_equal(plain, run_ruby(folder, instrumented, 1), "With mutant 1 active.")
    end
  end
end
