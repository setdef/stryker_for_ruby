# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "fileutils"
require "stryker/isolation"
require "tmpdir"

# What the orchestrator leaves behind when a signal interrupts it as it stops
# the parent that forks, with a stand-in for the parent's process, which ends
# itself when it is interrupted, as a `Child` does.
class ParentProcessSignalTest < Minitest::Test
  include IsolationStandIns

  # Stands in for a parent's process that a signal interrupts while it is
  # given its grace, and notes whether the folder stood when it ended.
  class InterruptedChild
    attr_reader :folder_stood

    def initialize(folder)
      @folder = folder
    end

    def end_within(_seconds)
      @folder_stood = Dir.exist?(@folder)
      raise(Interrupt)
    end
  end
  private_constant(:InterruptedChild)

  def test_a_signal_while_the_parent_is_given_its_grace_deletes_its_folder
    folder = Dir.mktmpdir("stryker-fork-")
    input, commands = IO.pipe
    results, output = IO.pipe
    [input, output].each(&:close)
    child = InterruptedChild.new(folder)
    pipes = Stryker::Isolation::ParentPipes.new(commands:, results:)

    assert_raises(Interrupt) { Stryker::Isolation::ParentProcess.new(child, pipes, folder).stop }
    assert_equal([true, false], [child.folder_stood, Dir.exist?(folder)])
  ensure
    FileUtils.remove_entry(folder, true) if folder
  end
end
