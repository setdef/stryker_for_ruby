# frozen_string_literal: true

require "bundler"

# Where the run's bundle keeps its gems, as an absolute path: a relative
# BUNDLE_PATH would otherwise be taken from this project's own folder.
explicit = Bundler.settings.path.explicit_path
gems = explicit ? { path: File.expand_path(explicit, Bundler.root) } : {}

# The project's own Gemfile, in place of the one that the run inherited.
Bundler::SharedHelpers.set_env("BUNDLE_GEMFILE", File.expand_path("../Gemfile", __dir__))
Bundler.reset!
Bundler.settings.temporary(gems) do
  # Bundler finds the installed gems only when it works their path out here,
  # with the absolute path set.
  Bundler.bundle_path
  Bundler.require
end

require "greeter"
require "minitest/autorun"
