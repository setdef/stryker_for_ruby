# frozen_string_literal: true

require_relative "sample_project"
require_relative "session"

module Stryker
  module Testing
    module IsolationContract
      module Sample
        private def with_sample(&)
          SampleProject.open(static: runs_static_mutants?, &)
        end

        private def isolated(sample, runs, concurrency: 1)
          Session.new(self, sample, concurrency).results(runs)
        end

        private def isolated_one(mutant_id, *names, timeout_ms: SampleProject::TIME_LIMIT_MS)
          with_sample { |sample| isolated(sample, [sample.run(mutant_id, *names, timeout_ms:)])[mutant_id] }
        end
      end
    end
  end
end
