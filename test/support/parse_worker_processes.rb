# frozen_string_literal: true

require_relative("parse_workers")
require "open3"

# What tests of one parse worker's process share: starting a worker that runs
# a program, a plain mutant to ask it about, and the errors it raises.
module ParseWorkerProcesses
  include ParseWorkers

  SERVE = 'require "stryker/instrumenter/parse_worker"; Stryker::Instrumenter::ParseWorker.serve'
  private_constant(:SERVE)

  def teardown
    @workers&.each(&:stop)
  end

  def start(program = SERVE)
    command = [RbConfig.ruby, "-I", LIB, "-e", "$stdout.sync = true; #{program}"]
    worker = Stryker::Instrumenter::ParseWorkerProcess.start(command)
    (@workers ||= []) << worker
    worker
  end

  # The first of +plains+: it replaces the 1 in "x = 1" by "y", which parses.
  def plain
    plains(1).first
  end

  # Waits until the process has ended, and Ruby has noticed.
  def wait_for_end(worker)
    sleep(0.01) while worker.running?
  end

  def asked(worker, plain)
    worker.give("x = 1\n")
    worker.ask(plain)
    worker
  end

  def failure(worker)
    assert_raises(Stryker::Instrumenter::Error) { yield(worker) }
  end
end
