# frozen_string_literal: true

require_relative("../../test_helper")
require "fileutils"
require "stryker/isolation/parent_process"
require "tmpdir"

# What stopping the parent that forks leaves undone when one step of it
# raises: none of the others.
class ParentProcessCleanupTest < Minitest::Test
  # Stands in for the pipes of a parent whose closing raises `error`, and
  # notes that it was asked to.
  class FailingPipes
    attr_reader :closed

    def initialize(error)
      @error = error
    end

    def close
      @closed = true
      raise(@error)
    end
  end
  private_constant(:FailingPipes)

  # Stands in for the parent's process, and notes each end it was asked for.
  class RecordingChild
    attr_reader :calls

    def initialize
      @calls = []
    end

    def end_within(seconds)
      @calls << [:end_within, seconds]
    end

    def kill_rest
      @calls << :kill_rest
    end
  end
  private_constant(:RecordingChild)

  def test_a_parent_whose_pipes_fail_to_close_is_still_ended_and_its_folder_deleted_before_the_error_raises
    folder = Dir.mktmpdir("stryker-fork-")
    child = RecordingChild.new
    parent = Stryker::Isolation::ParentProcess.new(child, FailingPipes.new(IOError), folder, 3)

    assert_raises(IOError) { parent.stop }
    assert_equal([[[:end_within, 3], :kill_rest], false], [child.calls, Dir.exist?(folder)])
  ensure
    FileUtils.remove_entry(folder, true) if folder
  end
end
