# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in stryker_for_ruby.gemspec
gemspec

# Opens a console.
gem "irb", "~> 1.18"
# Runs the tests.
gem "minitest", "~> 6.0"
# Validates the tests' reports against the report schema.
gem "json_schemer", "~> 2.5"
# Stubs objects in the tests.
gem "minitest-mock", "~> 5.27"
# Adds hooks that run around a whole test class, which the Minitest adapter's
# tests run, in processes of their own.
gem "minitest-hooks", "~> 1.5", require: false
# Runs a failing test again, which the Minitest adapter's tests check adds to
# the test's bucket, in processes of their own.
gem "minitest-retry", "~> 0.3", require: false
# Runs the tasks.
gem "rake", "~> 13.0"
# Measures test coverage, and fails below 100% of lines and branches.
gem "simplecov", "~> 1.3"
# Prepends a load_iseq of its own, which the loader's tests check the hook
# stays ahead of, in processes of their own. The runtime never loads it.
gem "bootsnap", "~> 1.26", require: false
# Autoloads the project that the loader's tests check comes through the hook,
# in processes of their own. The runtime never loads it.
gem "zeitwerk", "~> 2.8", require: false

# Lints the code and the Ruby in Markdown, with the plugins below.
gem "rubocop", "~> 1.21"
# Lints the Ruby code blocks in Markdown files.
gem "rubocop-md", "~> 3.0"
# Lints the tests.
gem "rubocop-minitest", "~> 0.41"
# Lints the RBS files.
gem "rubocop-on-rbs", "~> 2.2"
# Lints the gemspec for packaging mistakes.
gem "rubocop-packaging", "~> 0.6"
# Flags code that can run faster.
gem "rubocop-performance", "~> 1.27"
# Lints the Rake tasks.
gem "rubocop-rake", "~> 0.7"
# Flags code that is unsafe across threads.
gem "rubocop-thread_safety", "~> 0.8"

# Suggests where documentation is missing or weak.
gem "inch", "~> 0.4"
# Scores each file's complexity, in RubyCritic.
gem "flog", "4.8.0"
# Pinned as in ruby_quality's Gemfile template.
gem "ostruct", "~> 0.6.3"
# Generates the RDoc documentation and checks its coverage.
gem "rdoc", "~> 8.0"
# Rates the code's quality.
gem "rubycritic", "~> 5.0"
# Checks the RBS types against the code.
gem "steep", "~> 2.1"
