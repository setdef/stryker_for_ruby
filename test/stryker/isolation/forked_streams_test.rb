# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/forked_streams"
require "tmpdir"

# What a forked child changes about its streams, with a real pipe on every
# system.
class ForkedStreamsTest < Minitest::Test
  # The write end as the fork parent has it: an IO made from the descriptor's
  # number, with autoclose off, whose original IO is gone.
  def pipe_from_a_descriptor_number
    reader, writer = IO.pipe
    writer.autoclose = false
    [reader, IO.for_fd(writer.fileno, "w", autoclose: false)]
  end

  def crash(streams, stdout, stderr)
    streams.call(7, stdout, stderr)
    stderr.write("[BUG] crash\n")
  end

  def test_a_forked_child_closes_the_parents_pipe_and_writes_its_output_to_files_of_its_own
    reader, results = pipe_from_a_descriptor_number
    Dir.mktmpdir do |folder|
      streams = Stryker::Isolation::ForkedStreams.new(results, Stryker::Isolation::OutputFiles.new(folder))
      File.open(File::NULL, "w") { |stdout| File.open(File::NULL, "w") { |stderr| crash(streams, stdout, stderr) } }

      # End of file on the read end means no process holds the write end, as
      # the orchestrator needs when the parent ends while a child lives on.
      assert_equal([nil, "[BUG] crash\n"], [reader.read_nonblock(1, exception: false), streams.tail(7)])
    end
  ensure
    reader&.close
  end
end
