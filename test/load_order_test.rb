# frozen_string_literal: true

require_relative("test_helper")
require "open3"
require "rbconfig"

# Checks that SimpleCov starts before any file from lib loads, whichever test
# file the test task loads first. The task loads the files in a random order,
# and a lib file loaded before SimpleCov starts counts as uncovered, which
# fails the coverage gate on some runs only.
class LoadOrderTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  # Coverage.peek_result lists only the files loaded after SimpleCov started.
  PROBE = <<~RUBY
    require ARGV.fetch(0)
    measured = Coverage.peek_result.keys
    loaded = $LOADED_FEATURES.select { |feature| feature.start_with?(File.join(Dir.pwd, "lib") + "/") }
    exit!((loaded - measured).empty? ? 0 : 1)
  RUBY
  private_constant(:ROOT, :PROBE)

  def test_every_test_file_starts_simplecov_before_lib_loads
    paths = Dir.glob("test/**/*.rb", base: ROOT)
    late = paths.reject { |path| starts_simplecov_first?(path) }

    assert_empty(late, "These files load a lib file before SimpleCov starts.")
  end

  def starts_simplecov_first?(path)
    command = [RbConfig.ruby, "-Ilib:test", "-e", PROBE, File.join(ROOT, path)]
    _output, _errors, status = Open3.capture3(*command, chdir: ROOT)
    status.success?
  end
end
