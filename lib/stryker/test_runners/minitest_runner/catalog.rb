# frozen_string_literal: true

require_relative "../../test"
require_relative "../../unsupported_error"
require_relative "runnable_method"

module Stryker
  module TestRunners
    class MinitestRunner
      class Catalog
        ANONYMOUS = "The test class %<class>p, with the tests %<tests>s, has no name, " \
          "so Stryker (for Ruby) can't give its tests IDs that stand for them in another process."
        TWICE = "Two tests have the ID %<id>p, so Stryker (for Ruby) can't tell which one the ID stands for. " \
          "Give one of their classes, or one of their describe blocks, another name."
        private_constant(:ANONYMOUS, :TWICE)

        def self.take(root)
          # minitest/autorun's at_exit block runs every class in this list.
          # Emptying it keeps a project process that exits normally from
          # running the project's tests again, outside any test's bucket.
          registry = ::Minitest::Runnable.runnables
          classes = registry.dup
          registry.clear
          # Minitest::Test.runnable_methods seeds Ruby's random numbers with
          # Minitest.seed, and Minitest.run sets it, which the adapter never
          # calls. A fixed seed gives every process the same random numbers.
          ::Minitest.seed ||= 0
          new(classes, root)
        end

        def initialize(classes, root)
          @root = root
          @methods = {}
          classes.each { |klass| add(klass) }
        end

        def tests
          @methods.each_value.map(&:test)
        end

        def runnable_methods(ids)
          ids.map { |id| @methods.fetch(id) { raise(ArgumentError, "No test has the ID #{id.inspect}.") } }
        end

        private def add(klass)
          names = klass.runnable_methods.sort
          return if names.empty?

          prefix = klass.name or raise(UnsupportedError, format(ANONYMOUS, class: klass, tests: names.join(", ")))
          names.each { |name| add_method(klass, "#{prefix}##{name}", name) }
        end

        private def add_method(klass, id, name)
          raise(UnsupportedError, format(TWICE, id:)) if @methods.key?(id)

          file = klass.instance_method(name).source_location&.first
          test = Test.new(id:, name:, file: file && @root.relative(file), location: nil)
          @methods[id] = RunnableMethod.new(klass, name, test)
        end
      end
    end
  end
end
