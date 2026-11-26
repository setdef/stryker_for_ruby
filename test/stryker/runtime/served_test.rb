# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime/served"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks the record of the files that the hook served.
class ServedTest < Minitest::Test
  include RuntimeProcess

  # Starts an add that stops inside the Set, and prints whether a read that
  # starts then is still waiting 0.1 seconds later.
  BLOCKED_READ = <<~RUBY
    require "stryker/runtime/served"
    served = Stryker::Runtime::Served.new
    begun = Queue.new
    release = Queue.new
    slow = Object.new
    slow.define_singleton_method(:hash) do
      begun << true
      release.pop
      1
    end
    adder = Thread.new { served.add(slow) }
    begun.pop
    reader = Thread.new { served.include?("/tmp/cache/0.rb") }
    puts reader.join(0.1).nil?
    release << true
    adder.join
    reader.join
  RUBY
  private_constant(:BLOCKED_READ)

  def test_a_file_the_hook_served_is_recorded
    served = Stryker::Runtime::Served.new

    assert_nil(served.add("/tmp/cache/0.rb"))
    assert_includes(served, "/tmp/cache/0.rb")
  end

  def test_a_file_the_hook_did_not_serve_is_not_recorded
    refute_includes(Stryker::Runtime::Served.new, "/tmp/cache/0.rb")
  end

  # Two threads can load two files at once, and each load reaches the hook on
  # the thread that loads it. The add here stops while it holds whatever lock
  # it takes, and a read on another thread has to wait for it. A process of
  # its own starts the threads.
  def test_a_read_waits_for_an_add_that_another_thread_has_begun
    assert_equal("true\n", run_program(BLOCKED_READ).first)
  end
end
