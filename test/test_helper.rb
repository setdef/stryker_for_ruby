# frozen_string_literal: true

# SimpleCov starts before anything from lib loads, so it sees every line.
require "simplecov"

SimpleCov.start do
  # A deprecated SimpleCov setting raises instead of warning.
  deprecations(:raise)
  cover("lib/**/*.rb")
  cover("tasks/critic_faults.rb")
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

# The runtime starts a Ractor when a test requires it, on Ruby 4.0 and later,
# and writes a line to standard error about it unless this warning is off.
# test/stryker/runtime/dry_run_test.rb checks the line in processes of its
# own.
Warning[:experimental] = false

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "stryker"
