# frozen_string_literal: true

require_relative("../test_helper")
require "etc"
require "fileutils"
require "stryker/configure"
require "tmpdir"

# Builds a project folder in a temporary place and runs Configure on it, so
# that the tests of Configure read real files.
module ConfigProject
  # Configures a project that has the files, and a test/ folder unless the
  # files say otherwise. A name that ends in a slash is a folder, and its
  # value is nil.
  def configure(files = {}, **)
    configure_exactly({ "test/": nil }.merge(files), **)
  end

  def configure_exactly(files = {}, processors: Etc.nprocessors, **arguments)
    Dir.mktmpdir do |root|
      files.each do |name, text|
        path = File.join(root, name.to_s)
        text ? File.write(path, text) : FileUtils.mkdir_p(path)
      end
      Stryker::Configure.new(processors:).call(root:, **arguments)
    end
  end

  def refusal(files = {}, **)
    assert_raises(Stryker::ConfigError) { configure(files, **) }
      .message
  end

  def refusal_exactly(files = {}, **)
    assert_raises(Stryker::ConfigError) { configure_exactly(files, **) }
      .message
  end
end
