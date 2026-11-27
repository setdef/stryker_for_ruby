# frozen_string_literal: true

require_relative("../test_helper")

# What a test asks of the child processes that it, or the code under test,
# started.
module ChildProcesses
  # Whether the child process +pid+ has not ended, by what Ruby has learned
  # of it. Process.kill(0, pid) asks the system instead, and on Windows it
  # now and then finds a process that Ruby has already waited for.
  def running?(pid)
    Process.wait(pid, Process::WNOHANG).nil?
  rescue Errno::ECHILD
    false
  end
end
