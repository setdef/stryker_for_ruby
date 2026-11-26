# frozen_string_literal: true

require "minitest/test_task"

# Clear the default test task created by Minitest::TestTask if it exists
Rake::Task["test"].clear if Rake::Task.task_defined?("test")

desc "Run all tests"
task test: "test:ruby"

namespace :test do
  # Create a specific Minitest task for Ruby core tests
  Minitest::TestTask.create(:core) do |t|
    t.test_globs = ["test/**/*.rb"]
  end

  desc "Run all Ruby tests"
  task ruby: ["test:core"]
end
