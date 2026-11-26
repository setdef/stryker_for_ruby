# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "stryker/test_runners/minitest_runner"
require "stryker/testing"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("loader_project")

# Small Minitest projects for the Minitest adapter's tests, each written to a
# new folder. Every .rb file under test/ is one of this suite's own files, so
# the projects are written from strings instead of kept there.
module MinitestProject
  include LoaderProject

  # The start of a program that loads the adapter and makes an observer that
  # prints each event, one line each, for a process of its own.
  ADAPTER = <<~RUBY
    require "stryker/test_runners/minitest_runner"

    class Heard
      def test_started(test) = puts("started \#{test.id}")
      def test_finished(result) = puts("finished \#{result.test.id} \#{result.status}")
    end
  RUBY
  public_constant(:ADAPTER)

  # Writes +files+, each a path in the project and its source, to a new
  # folder, and returns the folder.
  def minitest_project(files)
    root = folder
    files.each do |path, source|
      file = File.join(root, path.to_s)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, source)
    end
    root
  end

  # An adapter for the project of +files+, built with +options+, with its
  # tests already loaded into this process.
  def loaded(files, **)
    Stryker::TestRunners::MinitestRunner.new(minitest_project(files), **).tap(&:load_tests)
  end

  # Runs the tests with +ids+ through +runner+, and returns their results.
  def run_ids(runner, *ids, bail: false)
    runner.run(ids, bail:, observer: Stryker::Testing::Observer.new)
  end

  # The test with +id+ among the tests +runner+ lists. The first adapter that
  # loads in this process also lists this suite's own tests.
  def listed(runner, id)
    runner.load_tests.find { |test| test.id == id }
  end
end
