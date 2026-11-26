# frozen_string_literal: true

require_relative("../test_helper")
require "tmpdir"

# Writes text to a file in a temporary folder, for the tests of the adapters
# that read configuration files.
module ConfigFiles
  def in_file(text)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "stryker.config")
      File.write(path, text)
      yield(path)
    end
  end
end
