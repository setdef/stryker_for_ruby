# frozen_string_literal: true

module Stryker
  module TestRunners
    class MinitestRunner
      module InlineExecutor
        def self.around
          saved = ::Minitest.parallel_executor
          ::Minitest.parallel_executor = self
          begin
            yield
          ensure
            ::Minitest.parallel_executor = saved
          end
        end

        def self.<<(job)
          klass, name, reporter = job
          ::Minitest::Runnable.run(klass, name, reporter)
        end
      end
    end
  end
end
