# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "stryker_for_ruby"
  # Bundler evaluates this file before the tests start SimpleCov, so it reads
  # the version as text. Requiring lib/stryker/version would run its lines
  # before coverage measures them.
  spec.version = File.read(File.expand_path("lib/stryker/version.rb", __dir__))[/VERSION = "([^"]+)"/, 1]
  spec.authors = ["setdef"]
  spec.summary = "Mutation testing for Ruby and ERB."
  spec.description = spec.summary
  spec.homepage = "https://github.com/setdef/stryker_for_ruby"
  spec.license = "Apache-2.0"

  # Ruby 3.3 and 3.4 are unsupported, and nothing blocks them: loading the
  # runtime on one prints a notice that links to docs/older-ruby.md. A floor
  # of 4.0 here would make Bundler and RubyGems refuse the gem there.
  spec.required_ruby_version = ">= 3.3"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "https://forum.setdef.com/c/stryker-for-ruby"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/trunk/CHANGELOG.md"

  spec.files = Dir["exe/*", "lib/**/*.rb", "sig/**/*.rbs", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.bindir = "exe"
  spec.executables = ["stryker"]
  spec.require_paths = ["lib"]

  # Only the orchestrator loads these, never a process that loads the
  # project's code (docs/contributors/decisions/0003). Ruby 3.3 bundles Prism 0.19.0,
  # which refract can't use, so the gem needs the Prism gem. Prism 1.7 is the
  # first release that parses with the syntax of Ruby 4.0 and 4.1. regexp_parser
  # 2.12 is the first release that knows Ruby 4.0's Unicode properties, which the
  # Regex mutator reads.
  spec.add_dependency("prism", ">= 1.7")
  spec.add_dependency("refract", "~> 2.0")
  spec.add_dependency("regexp_parser", "~> 2.12")
end
