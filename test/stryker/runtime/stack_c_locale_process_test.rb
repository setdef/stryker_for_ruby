# frozen_string_literal: true

require_relative("../../support/runtime_process")
require "tmpdir"

# Checks the stack check in a process that starts with the C locale, where Ruby
# tags the path of a frame US-ASCII on some systems, though the paths that the
# check looks for are UTF-8, as the cache's index gives them. The test names a
# file with a letter outside ASCII, which is the case when a project's folder
# holds a user's name.
class StackCLocaleProcessTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  def test_a_file_with_a_letter_outside_ascii_in_its_name_is_found_loading_under_the_c_locale
    Dir.mktmpdir do |folder|
      file = File.join(File.realpath(folder), "café.rb")
      File.write(file, "Thread.current[:found] = Stryker::Runtime::Stack.loading?(Thread.current[:paths])\n")
      program = "require 'stryker/runtime'\nfile = Dir.glob(#{File.join(folder, '*.rb').inspect}).first\n" \
        "Thread.current[:paths] = Set[Stryker::Runtime::PathKey.of(File.realpath(file))]\n" \
        "load(file)\np Thread.current[:found]"

      assert_equal("true\n", run_program(program, { LC_ALL: "C", LANG: "C" }).first)
    end
  end
end
