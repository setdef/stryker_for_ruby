# frozen_string_literal: true

require "inch/rake"
require "rubocop/rake_task"
require "rubycritic/rake_task"
require_relative("../critic_faults")

RuboCop::RakeTask.new

# The floor for RubyCritic's overall score. It may rise, never fall.
RUBYCRITIC_MINIMUM_SCORE = 95
RUBYCRITIC_REPORT_DIR = "tmp/rubycritic"

# RubyCritic runs in a shell so a failing score can't exit the rake process,
# then the task reads its JSON report: every file must be rated A, with no
# smell from reek or flay.
desc "Run RubyCritic: every file rated A, no smells, no duplication, a score of at least #{RUBYCRITIC_MINIMUM_SCORE}"
task :rubycritic do
  report = File.join(RUBYCRITIC_REPORT_DIR, "report.json")
  FileUtils.rm_f(report)
  score_ok = system(
    "bundle exec rubycritic --no-browser --format json --path #{RUBYCRITIC_REPORT_DIR} " \
      "--minimum-score #{RUBYCRITIC_MINIMUM_SCORE} lib sig"
  )
  abort("RubyCritic wrote no report.") unless File.exist?(report)

  faults = CriticFaults.in_report(File.read(report)).map { |fault| "  #{fault}" }
  abort("RubyCritic faults:\n#{faults.join("\n")}") unless faults.empty?
  abort("RubyCritic's score is below #{RUBYCRITIC_MINIMUM_SCORE}.") unless score_ok
end

Inch::Rake::Suggest.new("doc:suggest", "lib/**/*.rb", "sig/**/*.rbs") do |suggest|
  suggest.args << ""
end

namespace :reuse do
  desc "Run the REUSE Tool to confirm REUSE compliance"
  task :lint do
    sh("reuse lint")
  end
end

desc "Run the REUSE Tool to confirm REUSE compliance"
task reuse: "reuse:lint"

namespace :lint do
  desc "Check that every public class and method has RDoc"
  task :safe_rdoc_coverage do
    sh("bundle exec rake rdoc:coverage")
  end

  desc "Run the documentation lints"
  task docs: %w[safe_rdoc_coverage rubycritic reuse:lint]

  desc "Run the code lints"
  task code: %w[rubocop rubycritic]

  desc "Run the license lint"
  task licenses: %w[reuse:lint]

  desc "Run every lint"
  task all: %w[docs code licenses rbs]

  namespace :fix do
    desc "Auto-fix RuboCop offenses (most aggressive)"
    task :rubocop do
      sh("bundle exec rubocop --autocorrect-all")
    end

    desc "Run all auto-fix tasks"
    task all: %w[lint:fix:rubocop]
  end
end

desc "Run all lint auto-fix tasks"
task "lint:fix": "lint:fix:all"

# Aliases for convenience
desc "Auto-fix RuboCop offenses (alias of lint:fix:rubocop)"
task "rubocop:autocorrect_all": "lint:fix:rubocop"

desc "Run all lint tasks"
task lint: "lint:all"
