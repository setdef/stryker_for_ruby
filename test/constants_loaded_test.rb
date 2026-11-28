# frozen_string_literal: true

require_relative("support/required_constants")
require_relative("test_helper")

# Checks that each test file loads the files that define the constants it
# mentions. The test task loads the files in a random order, so a test file
# that leans on a constant another test file loaded fails when it runs
# alone, or when the order puts it first. Running each file in a process of its
# own would show that too, at the cost of a process for each of the test files.
#
# The check can't see a constant written without its full name inside a
# nesting, such as `Config` in `module Stryker`, or a file loaded by a
# `require` whose argument isn't a literal string. See RequiredConstants for
# what to write instead.
class ConstantsLoadedTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  private_constant(:ROOT)

  def test_every_test_file_loads_the_files_that_define_the_constants_it_mentions
    required = RequiredConstants.new(project_files, [File.join(ROOT, "lib"), File.join(ROOT, "test")])
    lacking = test_files.to_h { |path| [path.delete_prefix("#{ROOT}/"), required.missing_from(path)] }

    assert_empty(lacking.reject { |_path, names| names.empty? }, "These files mention constants they do not load")
  end

  # The test task leaves out the sample projects in test/fixtures.
  private def project_files
    Dir.glob("{lib,tasks,test}/**/*.rb", base: ROOT).grep_v(%r{\Atest/fixtures/}).map { |path| File.join(ROOT, path) }
  end

  private def test_files
    project_files.grep(/_test\.rb\z/)
  end
end
