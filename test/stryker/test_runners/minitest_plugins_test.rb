# frozen_string_literal: true

require_relative("../../support/minitest_project")

# The Minitest adapter with the Minitest plugins it is built to run with,
# minitest-retry and minitest-hooks, each in a project process of its own.
class MinitestPluginsTest < Minitest::Test
  include MinitestProject

  parallelize_me!

  RETRIED = { "test/flaky_test.rb": <<~RUBY }.freeze
    require "minitest/autorun"
    require "minitest/retry"
    Minitest::Retry.use!(verbose: false)

    class FlakyTest < Minitest::Test
      @@tries = 0

      def test_flaky
        @@tries += 1
        RECORDER.record([@@tries])
        assert_operator(@@tries, :>, 1)
      end
    end
  RUBY
  HOOKED = { "test/hooked_test.rb": <<~RUBY }.freeze
    require "minitest/autorun"
    require "minitest/hooks/test"

    class HookedTest < Minitest::Test
      include Minitest::Hooks

      def before_all
        super
        puts("before_all")
      end

      def test_hooked = puts("ran HookedTest#test_hooked")
    end

    class BrokenHookTest < Minitest::Test
      include Minitest::Hooks

      def before_all = raise("Raised in before_all.")
      def test_never = puts("ran BrokenHookTest#test_never")
    end
  RUBY
  # What the program with HOOKED prints first: the hook's line inside the
  # first test, and no line from the test whose hook raised.
  HOOKS_HEARD = [
    "started HookedTest#test_hooked",
    "before_all",
    "ran HookedTest#test_hooked",
    "finished HookedTest#test_hooked passed",
    "started BrokenHookTest#test_never",
    "finished BrokenHookTest#test_never failed",
    "true",
  ].freeze
  private_constant(:HOOKED, :HOOKS_HEARD, :RETRIED)

  def test_a_test_that_minitest_retry_runs_again_adds_to_the_bucket_it_already_has
    output, = run_program(<<~RUBY, gems: %w[minitest minitest-retry])
      #{ADAPTER}
      require "stryker/runtime/recorder"
      RECORDER = Stryker::Runtime::Recorder.new
      runner = Stryker::TestRunners::MinitestRunner.new(#{minitest_project(RETRIED).inspect})
      runner.load_tests
      result = runner.run(["FlakyTest#test_flaky"], bail: false, observer: RECORDER).first
      puts(result.status, RECORDER.tests.map { |test, bucket| [test.id, bucket.to_a].inspect })
    RUBY

    assert_equal(["passed", '["FlakyTest#test_flaky", [1, 2]]'], output.lines(chomp: true).first(2))
  end

  def test_minitest_hooks_run_their_before_all_hook_around_each_chosen_test
    output, = run_program(<<~RUBY, gems: %w[minitest minitest-hooks])
      #{ADAPTER}
      runner = Stryker::TestRunners::MinitestRunner.new(#{minitest_project(HOOKED).inspect})
      runner.load_tests
      results = runner.run(%w[HookedTest#test_hooked BrokenHookTest#test_never], bail: false, observer: Heard.new)
      puts(results.last.failure_message.include?("Raised in before_all."))
    RUBY

    assert_equal(HOOKS_HEARD, output.lines(chomp: true).first(HOOKS_HEARD.size))
  end
end
