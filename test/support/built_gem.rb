# frozen_string_literal: true

require_relative "../test_helper"
require "rubygems/package"

# A gem file as `gem build` makes it, for the tests of what a release checks
# about the gem it publishes.
module BuiltGem
  # Builds the gem +name+ at +version+ in +dir+, and returns its path.
  def build_gem(dir, name, version)
    spec = Gem::Specification.new do |gem|
      gem.name = name
      gem.version = version
      gem.summary = "A gem."
      gem.authors = ["setdef"]
      gem.files = []
    end
    path = File.join(dir, "#{name}-#{version}.gem")
    Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) { Gem::Package.build(spec, true, false, path) }
    path
  end
end
