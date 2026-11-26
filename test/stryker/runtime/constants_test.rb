# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# Checks which of the runtime's constants a caller can reach.
class ConstantsTest < Minitest::Test
  # The messages are the runtime's own, and no caller should match on them.
  def test_the_runtimes_messages_and_labels_are_private
    constants = [
      [Stryker::Runtime::Buckets, :NO_TEST_RUNNING],
      [Stryker::Runtime::Stack, :TOP_LEVEL_LABELS],
      [Stryker::Runtime::Recorder, :SECOND_DRY_RUN],
    ]

    assert_empty(constants.select { |owner, name| owner.constants.include?(name) })
  end
end
