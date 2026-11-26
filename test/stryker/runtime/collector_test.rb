# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks the collector with stand-ins for Ractor, because Coverage counts no
# line that runs outside the main Ractor, and a real collector would start a
# Ractor in the test process. first_ractor_process_test.rb and
# process_test.rb start real ones.
class CollectorTest < Minitest::Test
  # An inbox that hands out its messages in order, and then raises
  # StopIteration, which ends the collector's loop.
  Inbox = Struct.new(:messages) do
    def receive
      raise(StopIteration) if messages.empty?

      messages.shift
    end
  end

  # A reply port that hands out what it was given.
  Reply = Struct.new(:answer) do
    def receive
      answer
    end
  end
  private_constant(:Inbox, :Reply)

  def started(ractor, reply = nil)
    Stryker::Runtime::Collector.new.started(ractor, reply)
  end

  def test_it_answers_each_drain_with_the_messages_since_the_last_one
    replies = []
    Stryker::Runtime::Collector.serve(Inbox.new([[7], "lib/invoice.rb", :drain, :drain, [8], :drain]), replies)

    assert_equal([["lib/invoice.rb", [7]], [], [[8]]], replies)
  end

  # A Ractor can send millions of hits between two drains, so the collector
  # keeps each mutant and each file once.
  def test_it_keeps_each_mutant_and_each_file_once_between_drains
    replies = []
    messages = [[7], [7, 8], "lib/invoice.rb", [8], "lib/tax.rb", "lib/invoice.rb", :drain]
    Stryker::Runtime::Collector.serve(Inbox.new(messages), replies)

    assert_equal([["lib/invoice.rb", "lib/tax.rb", [7, 8]]], replies)
  end

  def test_no_collector_is_built_on_a_ruby_without_ractor_ports
    assert_nil(Stryker::Runtime::Collector.build(Module.new))
  end

  # Ractor's ancestors include Object, so a top-level Port in the project would
  # be inherited the same way.
  def test_an_inherited_port_is_not_a_ractor_port
    ported = Class.new { const_set(:Port, Class.new) }

    assert_nil(Stryker::Runtime::Collector.build(Class.new(ported)))
  end

  def test_a_collector_is_built_without_starting_a_ractor
    collector = Stryker::Runtime::Collector.build(Class.new { const_set(:Port, Class.new) })

    assert_equal([Stryker::Runtime::Collector, false], [collector.class, collector.started?])
  end

  def test_a_started_collector_says_so
    assert_predicate(started([]), :started?)
  end

  def test_a_message_goes_to_the_collector_ractor
    sent = []
    collector = started(sent)

    assert_same(collector, collector << [7])
    assert_equal([[7]], sent)
  end

  def test_a_message_to_a_collector_that_has_not_started_raises
    error = assert_raises(Stryker::UnsupportedError) { Stryker::Runtime::Collector.new << [7] }

    assert_includes(error.message, "started before Stryker (for Ruby) loaded")
  end

  def test_a_drain_asks_the_collector_ractor_and_returns_its_answer
    sent = []
    collector = started(sent, Reply.new([[7]]))

    assert_equal([[[7]], [:drain]], [collector.drain, sent])
  end

  def test_a_collector_that_has_not_started_drains_nothing
    assert_empty(Stryker::Runtime::Collector.new.drain)
  end

  # A holder made shareable holds the collector, which must still start
  # afterwards.
  def test_a_collector_stays_writable_in_a_shareable_holder
    collector = Stryker::Runtime::Collector.new
    Ractor.make_shareable(Stryker::Runtime::Recording.new(collector:))

    assert_predicate(collector.started([], nil), :started?)
  end
end
