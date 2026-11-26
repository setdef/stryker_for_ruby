# frozen_string_literal: true

require_relative("../../support/parse_worker_processes")

# Checks that a parse worker that doesn't finish a line in time is killed,
# and that the error says so.
class ParseWorkerTimeLimitTest < Minitest::Test
  include ParseWorkerProcesses

  # A worker that takes the job and then writes +program+, with a limit of 0.2 seconds.
  def silent(program)
    worker = asked(start("$stdin.gets; $stdin.gets; #{program}"), plain)
    worker.wait_at_most(0.2)
    worker
  end

  def test_a_worker_that_does_not_answer_in_time_stops_and_raises
    error = failure(silent("sleep")) { |worker| worker.verdict(plain) }

    expected = "A parse worker gave no answer for the plain mutant of mutant 1 in lib/x.rb within 0.2 seconds."

    assert_equal(expected, error.message)
  end

  def test_a_worker_that_does_not_answer_in_time_is_not_running_after
    worker = silent("sleep")
    failure(worker) { |slow| slow.verdict(plain) }

    refute_predicate(worker, :running?)
  end

  def test_a_worker_that_stops_in_the_middle_of_a_line_does_not_answer_in_time
    error = failure(silent("$stdout.write('{\"val'); sleep")) { |worker| worker.verdict(plain) }

    assert_includes(error.message, "gave no answer for")
  end

  def test_the_error_gives_the_last_lines_the_worker_wrote_to_standard_error
    worker = asked(start("$stdin.gets; $stdin.gets; warn('slow'); puts('{\"valid\":true}'); sleep"), plain)
    worker.verdict(plain)
    worker.wait_at_most(0.2)

    error = failure(worker) { |silent| silent.verdict(plain) }

    assert_includes(error.message, "seconds.\nThe last lines it wrote to standard error:\nslow")
  end

  def test_a_worker_that_answers_in_time_gives_its_verdict
    worker = asked(start, plain)
    worker.wait_at_most(20.0)

    assert(worker.verdict(plain))
  end
end
