# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module IsolationContract
      module Cleanup
        include Sample

        def test_every_process_has_ended_when_stop_returns
          left = with_sample do |sample|
            isolated(sample, [sample.run(SampleProject::HARMLESS, :passes)])
            SampleProcesses.running(sample.root)
          end

          assert_empty(left)
        end

        def test_every_process_has_ended_when_the_block_raises
          left = with_sample { |sample| Session.new(self, sample, 2).running_after_a_raise }

          assert_empty(left)
        end
      end
    end
  end
end
