# frozen_string_literal: true

require_relative("../../support/parse_worker_processes")

# Checks that the error of a failing parse worker ends with what the worker
# wrote to its standard error, and that the file that holds it goes.
class ParseWorkerStandardErrorTest < Minitest::Test
  include ParseWorkerProcesses

  # The start of the message about plain mutant 1, which a worker +fault+ describes.
  def job_message(fault)
    "A parse worker #{fault} the plain mutant of mutant 1 in lib/x.rb"
  end

  def test_a_worker_that_ends_gives_the_last_lines_it_wrote_to_standard_error
    worker = asked(start("$stdin.gets; $stdin.gets; warn('first'); warn('boom'); exit 2"), plain)

    error = failure(worker) { |ended| ended.verdict(plain) }

    expected = "#{job_message('ended while it parsed')}.\nThe last lines it wrote to standard error:\nfirst\nboom"

    assert_equal(expected, error.message)
  end

  def test_a_worker_that_writes_something_else_gives_the_last_lines_it_wrote_to_standard_error
    worker = asked(start("$stdin.gets; $stdin.gets; warn('boom'); puts('oops'); sleep"), plain)

    error = failure(worker) { |writing| writing.verdict(plain) }

    assert_includes(error.message, "with \"oops\", not a result.\nThe last lines it wrote to standard error:\nboom")
  end

  def test_a_worker_that_has_ended_gives_the_last_lines_it_wrote_to_standard_error_when_asked
    worker = start("warn('boom'); exit 1")
    wait_for_end(worker)

    error = failure(worker) { |ended| asked(ended, plain) }

    assert_includes(error.message, "The last lines it wrote to standard error:\nboom")
  end

  def test_a_worker_that_writes_a_lot_to_standard_error_does_not_hang
    # A pipe that nothing reads holds 64 KiB or less, and the worker would wait for ever to write more.
    worker = asked(start("$stdin.gets; $stdin.gets; $stderr.write('x' * 200_000); puts('{\"valid\":true}')"), plain)

    assert(worker.verdict(plain))
  end

  def test_stop_deletes_the_file_of_standard_error
    input, output, waiter = Open3.popen2(RbConfig.ruby, "-e", "sleep")
    errors = Stryker::Instrumenter::ParseWorkerStderr.open
    path = errors.stream.path
    Stryker::Instrumenter::ParseWorkerProcess.new(input, output, waiter, errors).stop

    refute_path_exists(path)
  end
end
