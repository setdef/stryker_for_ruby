# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks Stryker::Active in processes of their own: as the runtime sets it
# when it loads, as a forked child replaces it, and as other Ractors read it.
class ProcessTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  # Reads the active mutant's ID in the main Ractor and in another one.
  READ = <<~RUBY
    p [Stryker::Active.id, take_value(Ractor.new { Stryker::Active.id })]
  RUBY
  private_constant(:READ)

  def test_an_id_in_the_environment_is_active_from_the_start
    output, = run_program("require 'stryker/runtime'\n#{READ}", { STRYKER_ACTIVE_MUTANT: "7" })

    assert_equal("[7, 7]\n", output)
  end

  def test_with_no_id_in_the_environment_no_mutant_is_active
    output, = run_program("require 'stryker/runtime'\n#{READ}")

    assert_equal("[nil, nil]\n", output)
  end

  def test_the_holder_is_shareable
    output, = run_program("require 'stryker/runtime'\np Ractor.shareable?(Stryker::Active)")

    assert_equal("true\n", output)
  end

  def test_a_mutant_run_records_no_hit
    program = "require 'stryker/runtime'\np Stryker::Active.hit(7)\np Stryker::Runtime::RECORDER.static"

    assert_equal("nil\n#{Set.new.inspect}\n", run_program(program, { STRYKER_ACTIVE_MUTANT: "7" }).first)
  end

  def test_with_no_mutant_active_a_hit_is_recorded
    program = "require 'stryker/runtime'\np Stryker::Active.hit(7, 8)\np Stryker::Runtime::RECORDER.static"

    assert_equal("nil\n#{Set[7, 8].inspect}\n", run_program(program).first)
  end

  def test_a_hit_in_another_ractor_with_no_collector_fails_the_ractor
    program = <<~RUBY
      require "stryker/runtime"
      begin
        take_value(Ractor.new { Stryker::Active.hit(7) })
      rescue Ractor::RemoteError => error
        p [error.cause.class, error.cause.message.include?("Ruby 4.0"), Stryker::Runtime::RECORDER.static.to_a]
      end
    RUBY

    assert_equal("[Stryker::UnsupportedError, true, []]\n", run_program(program).first)
  end

  def test_a_hit_in_another_ractor_in_a_mutant_run_records_nothing
    program = "require 'stryker/runtime'\np take_value(Ractor.new { Stryker::Active.hit(7) })"

    assert_equal("nil\n", run_program(program, { STRYKER_ACTIVE_MUTANT: "7" }).first)
  end

  def test_a_mutant_run_records_no_load
    program = <<~RUBY
      require "stryker/runtime"
      Stryker::Runtime::RECORDER.test_started(:first)
      p Stryker::Active.load_began("/app/lib/invoice.rb")
      p Stryker::Runtime::RECORDER.loaded.to_a
    RUBY

    assert_equal("nil\n[]\n", run_program(program, { STRYKER_ACTIVE_MUTANT: "7" }).first)
  end

  def test_code_compiled_before_the_replacement_reads_the_new_holder_in_every_ractor
    program = <<~RUBY
      require "stryker/runtime"
      def active = ::Stryker::Active.id
      before = active
      Stryker::Runtime.activate_mutant(9)
      p [before, active, take_value(Ractor.new { ::Stryker::Active.id })]
    RUBY

    assert_equal(["[nil, 9, 9]\n", []], run_program(program))
  end
end
