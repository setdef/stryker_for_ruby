# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks the collector with stand-ins for Ractor, because Coverage counts no
# line that runs outside the main Ractor, and a real collector would start a
# Ractor in the test process. process_test.rb starts real ones.
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

  # A stand-in for Ractor on Ruby 4.0 and later. Its new returns the
  # arguments it got, and the block, which it doesn't run.
  module PortedRactor
    Port = Class.new
    public_constant(:Port)

    def self.new(*arguments, &block)
      [arguments, block]
    end
  end
  private_constant(:Inbox, :PortedRactor, :Reply)

  def test_it_answers_each_drain_with_the_messages_since_the_last_one
    replies = []
    Stryker::Runtime::Collector.serve(Inbox.new([[7], "lib/invoice.rb", :drain, :drain, [8], :drain]), replies)

    assert_equal([[[7], "lib/invoice.rb"], [], [[8]]], replies)
  end

  def test_no_collector_starts_on_a_ruby_without_ractor_ports
    assert_nil(Stryker::Runtime::Collector.start(Module.new))
  end

  # Ractor's ancestors include Object, so a top-level Port in the project would
  # be inherited the same way.
  def test_an_inherited_port_is_not_a_ractor_port
    ported = Class.new { const_set(:Port, Class.new) }

    assert_nil(Stryker::Runtime::Collector.start(Class.new(ported)))
  end

  def test_a_collector_starts_with_a_reply_port_of_its_own
    collector = Stryker::Runtime::Collector.start(PortedRactor)
    arguments, block = collector.ractor

    assert_instance_of(PortedRactor::Port, collector.reply)
    assert_equal([collector.reply], arguments)
    assert_kind_of(Proc, block)
  end

  def test_a_message_goes_to_the_collector_ractor
    sent = []
    collector = Stryker::Runtime::Collector.new(ractor: sent, reply: nil)

    assert_same(collector, collector << [7])
    assert_equal([[7]], sent)
  end

  def test_a_drain_asks_the_collector_ractor_and_returns_its_answer
    sent = []
    collector = Stryker::Runtime::Collector.new(ractor: sent, reply: Reply.new([[7]]))

    assert_equal([[[7]], [:drain]], [collector.drain, sent])
  end
end
