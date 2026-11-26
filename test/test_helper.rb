# frozen_string_literal: true

# SimpleCov starts before anything from lib loads, so it sees every line.
require "simplecov"

SimpleCov.start do
  # A deprecated SimpleCov setting raises instead of warning.
  deprecations(:raise)
  cover("lib/**/*.rb")
  cover("tasks/build_cop.rb")
  cover("tasks/build_cop_blame.rb")
  cover("tasks/build_cop_step.rb")
  cover("tasks/commit_runs.rb")
  cover("tasks/critic_faults.rb")
  cover("tasks/github_api.rb")
  cover("tasks/ruby_doc_comments.rb")
  enable_coverage(:branch)
  minimum_coverage(line: 100, branch: 100)
  coverage(:line) { minimum(100, per: :file) }
  coverage(:branch) { minimum(100, per: :file) }
  refuse_coverage_drop
  # A run's figure comes from that run only. SimpleCov otherwise merges the
  # results of earlier runs still inside its merge timeout, so a partial run
  # right after a full one passes the minimum.
  merging(false)
end

require "minitest/autorun"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "stryker"
