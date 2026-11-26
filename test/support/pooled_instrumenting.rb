# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/instrumenter"

# Instruments for the site tests, and checks that a pool of parse workers
# gives the result that this process gives, so that the site tests' corpus
# proves the two ways of parsing the plain mutants alike.
module PooledInstrumenting
  # One pool for every test, so that its workers start once, and with a
  # threshold of 0, so that it parses even the smallest file.
  POOL = Stryker::Instrumenter::ParsePool.new(2, 0)
  # The pool serves one file at a time, and the site tests run in threads.
  LOCK = Mutex.new
  private_constant(:LOCK, :POOL)

  # No worker of the pool outlives the tests.
  Minitest.after_run { POOL.stop }

  # What the instrumenter makes of +source+ with +mutants+.
  def instrumented(source, mutants)
    alone = Stryker::Instrumenter.new(source).instrument(mutants)
    pooled = LOCK.synchronize { Stryker::Instrumenter.new(source, POOL).instrument(mutants) }

    assert_equal(alone, pooled, "A pool of parse workers gives another result.")
    alone
  end
end
