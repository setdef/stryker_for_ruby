# frozen_string_literal: true

require_relative "inline_executor"
require_relative "outcome"

module Stryker
  module TestRunners
    class MinitestRunner
      class RunnableMethod
        attr_reader :test

        def initialize(klass, name, test)
          @klass = klass
          @name = name
          @test = test
          @filter = /\A#{Regexp.escape(name)}\z/
        end

        def run(observer)
          observer.test_started(test)
          result = run_in_minitest
          observer.test_finished(result)
          result
        end

        private def run_in_minitest
          outcome = Outcome.new(@name)
          # run_suite runs the class's suite hooks as Minitest's own run does,
          # and the filter keeps it to this one method of the class.
          InlineExecutor.around { @klass.run_suite(outcome, include: @filter) }
          outcome.result(test)
        end

        # @dynamic test
      end
    end
  end
end
