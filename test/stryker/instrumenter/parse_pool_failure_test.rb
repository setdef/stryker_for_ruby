# frozen_string_literal: true

require_relative("../../support/parse_workers")

# Checks the errors of the pool of parse workers: each names the job, and
# each leaves no process running.
class ParsePoolFailureTest < Minitest::Test
  include ParseWorkers

  Pool = Stryker::Instrumenter::ParsePool
  SOURCE = "x = 1\n"
  private_constant(:Pool, :SOURCE)

  # The error that a pool of two stand-ins with the +behavior+ raises for one
  # plain mutant.
  def failure(behavior, folder)
    assert_raises(Stryker::Instrumenter::Error) do
      Pool.open(2, 1, worker_command(behavior, folder, 2)) { |pool| pool.valid(SOURCE, plains(1)) }
    end
  end

  def test_it_raises_when_a_worker_dies_and_names_the_job
    with_workers do |folder|
      expected = "A parse worker ended while it parsed the plain mutant of mutant 1 in lib/x.rb."

      assert_equal(expected, failure(:dies_after_taking_the_job, folder).message)
    end
  end

  def test_it_raises_when_a_worker_writes_something_that_is_not_json
    with_workers do |folder|
      expected = "A parse worker answered the plain mutant of mutant 1 in lib/x.rb with \"oops\", not a result."

      assert_equal(expected, failure(:answers_with_text, folder).message)
    end
  end

  def test_it_raises_when_a_worker_writes_json_that_is_not_a_verdict
    with_workers do |folder|
      message = failure(:answers_with_json_that_is_no_verdict, folder).message

      assert_includes(message, "answered the plain mutant of mutant 1 in lib/x.rb with \"{\\\"id\\\":999}\"")
    end
  end

  def test_it_raises_when_a_worker_ends_before_it_takes_the_job
    with_workers do |folder|
      expected = "A parse worker ended while it parsed the plain mutant of mutant 1 in lib/x.rb."

      assert_equal(expected, failure(:ends_at_once, folder).message)
    end
  end

  def test_it_raises_when_the_command_does_not_exist
    assert_raises(SystemCallError) do
      Pool.open(2, 1, ["stryker-no-such-command"]) { |pool| pool.valid(SOURCE, plains(1)) }
    end
  end

  def test_it_ends_every_worker_when_it_raises_and_is_not_stopped_after
    with_workers do |folder|
      pool = Pool.new(2, 1, worker_command(:answers_with_text, folder, 2))

      assert_raises(Stryker::Instrumenter::Error) { pool.valid(SOURCE, plains(1)) }
    end
  end
end
