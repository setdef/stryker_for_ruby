# frozen_string_literal: true

require_relative("../../support/minitest_project")
require "tmpdir"

# The test runner contract, against the Minitest adapter and a sample suite
# loaded into this process once.
class MinitestRunnerContractTest < Minitest::Test
  include Stryker::Testing::TestRunnerContract

  SAMPLE = <<~RUBY
    class ContractSampleTest < Minitest::Test
      Runs = Stryker::Testing::SampleRuns
      Contract = Stryker::Testing::TestRunnerContract

      def test_passes
        Runs.ran(:passes)
      end

      def test_fails
        Runs.ran(:fails)
        flunk(Contract::FAILURE)
      end

      def test_errors
        Runs.ran(:errors)
        raise(Contract::ERROR)
      end

      def test_skips
        Runs.ran(:skips)
        skip
      end
    end
  RUBY
  IDS = Stryker::Testing::TestRunnerContract::ROLES.to_h { |role| [role, "ContractSampleTest#test_#{role}"] }
  IDS.freeze

  # The adapter, built and loaded the first time a test asks for it. A test
  # file loads once in a process, so every test shares the one adapter.
  class Sample
    def runner
      @runner ||= Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "test"))
        File.write(File.join(root, "test", "contract_sample_test.rb"), SAMPLE)
        Stryker::TestRunners::MinitestRunner.new(root).tap(&:load_tests)
      end
    end
  end
  RUNNER = Sample.new
  private_constant(:IDS, :RUNNER, :SAMPLE, :Sample)

  def runner_under_test
    RUNNER.runner
  end

  def sample_test_ids
    IDS
  end

  def test_the_sample_suite_lists_one_test_for_each_role
    ids = runner_under_test.load_tests.map(&:id)

    assert_equal(IDS.values.to_set, ids.grep(/\AContractSampleTest#/).to_set)
  end
end
