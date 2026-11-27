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

  # The processes that the system lists, each as its process ID, its
  # parent's, whether it is running, and its command line. A process that has
  # ended and waits for its parent to reap it isn't running. Only on systems
  # with ps, which a test of a process that another process started needs:
  # Ruby can wait only for its own children, so running? finds no process
  # that a child started.
  def listed_processes
    IO.popen(%w[ps -A -o pid=,ppid=,stat=,command=], &:readlines).map do |line|
      pid, parent, state, command = line.strip.split(/\s+/, 4)
      { pid: Integer(pid), parent: Integer(parent), running: !state.start_with?("Z"), command: }
    end
  end

  # Whether the system lists the process +pid+ as running, whoever started it.
  def listed_running?(pid)
    listed_processes.any? { |process| process[:pid] == pid && process[:running] }
  end
end
