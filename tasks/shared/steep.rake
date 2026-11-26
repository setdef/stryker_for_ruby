# frozen_string_literal: true

require_relative("lint")

namespace :steep do
  desc "Run Steep type checker"
  task :check do
    sh("bundle exec steep check")
  end

  desc "Forbid 'untyped' in RBS files except approved exceptions"
  task :no_untyped do
    exceptions = File.expand_path("../rbs_exceptions.rb", __dir__)
    abort("tasks/rbs_exceptions.rb missing — re-scaffold to create it") unless File.exist?(exceptions)
    Lint.load(exceptions).enforce!(
      glob: "sig/**/*.rbs",
      pattern: /\buntyped\b/,
      reject_pattern: /^\s*#/,
      violation_name: "'untyped' in RBS files"
    )
  end
end

desc "Run Steep type checker (with no_untyped check)"
task steep: %w[steep:check steep:no_untyped]

namespace :lint do
  desc "Run RBS linting (no unapproved untyped)"
  task rbs: "steep:no_untyped"
end
