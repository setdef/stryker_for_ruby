# frozen_string_literal: true

require_relative("../test_helper")

# Stand-ins for what a watch drives, so that a test owns time: a clock that
# moves only when the test moves it, and a process that runs until the test
# ends it, with a pipe that only the test writes to.
module WatchStandIns
  # A clock that moves only when a test moves it, in seconds.
  class Clock
    def initialize
      @now = 100.0
    end

    def call
      @now
    end

    def advance(seconds)
      @now += seconds
      nil
    end
  end

  # A process that runs until the test ends it, and writes only what the test
  # writes to its pipe. Ending it closes the pipe, as the end of the only
  # process that holds the pipe's write end does.
  class ScriptedProcess
    Done = Struct.new(:exitstatus, :termsig)
    private_constant(:Done)

    # The reader of the pipe, and the seconds that each wait for the process
    # to end gave it.
    attr_reader :reader, :waits

    def initialize(exit_status = 0)
      @reader, @writer = IO.pipe
      @exit_status = exit_status
      @ended = false
      @waits = []
    end

    def write(text)
      @writer.write(text)
      nil
    end

    # The process ends. A +holding+ pipe stays open, as when a process that
    # the process started holds it.
    def finish(holding: false)
      @ended = true
      @writer.close unless holding
      nil
    end

    def ended?
      @ended
    end

    # Whether the process is still running when its time is up.
    def end_within(seconds)
      @waits << seconds
      @running = !ended?
    end

    def status
      Done.new(@exit_status, nil)
    end

    def kill_rest
      nil
    end

    def stop
      nil
    end

    def close
      [@reader, @writer].each { |io| io.close unless io.closed? }
    end
  end

  def after_teardown
    @scripted&.each(&:close)
    super
  end

  # A process of the test's own, which the test closes when it ends.
  def scripted_process(*)
    ScriptedProcess.new(*).tap { |made| (@scripted ||= []) << made }
  end

  # The test's clock.
  def clock
    @clock ||= Clock.new
  end
end
