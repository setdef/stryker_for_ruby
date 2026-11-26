# frozen_string_literal: true

require_relative("isolation_stand_ins")

# Stand-ins for what the code in a project process drives: a test runner, the
# finisher, and the runtime.
module ProjectSideStandIns
  # A test runner that runs every test it's given, with +status+, and records
  # the calls it gets.
  class Runner
    attr_reader :calls

    def initialize(status = "passed")
      @status = status
      @calls = []
    end

    def load_tests
      @calls << [:load_tests]
      []
    end

    def run(test_ids, bail:, observer:)
      @calls << [:run, test_ids, bail]
      test_ids.map do |id|
        test = Stryker::Test.new(id:, name: id, file: nil, location: nil)
        observer.test_started(test)
        Stryker::TestResult.new(test:, status: @status, failure_message: nil, duration_ms: 1.0).tap do |result|
          observer.test_finished(result)
        end
      end
    end
  end

  # Runs the block through the report, and records the code that would end
  # the process.
  class Finisher
    attr_reader :code

    def call(report, &)
      @code = report.conclude(&)
    end
  end

  # Records the mutant it makes active.
  class Runtime
    attr_reader :active

    def activate_mutant(id)
      @active = id
    end
  end

  # A mode of the entry point that records what it was built with.
  Mode = Struct.new(:runner, :details) do
    def self.build(runner, details)
      new(runner, details)
    end

    def call
      :called
    end
  end

  public_constant(:Mode)

  # Records the arguments of each call it gets.
  class Calls
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(*arguments)
      @calls << arguments
    end
  end

  # A loader that records the cache's directory it installs from.
  class Loader
    attr_reader :installed

    def install(directory)
      @installed = directory
    end
  end
end
