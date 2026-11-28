# frozen_string_literal: true

require_relative("../../support/runtime_process")
require "tmpdir"

# Checks the stack check in a process that starts with the C locale, where Ruby
# tags the path of a frame US-ASCII on some systems, though the paths that the
# check looks for are UTF-8, as the cache's index gives them. The test names a
# file with a letter outside ASCII, which is the case when a project's folder
# holds a user's name. The program tags its pattern as the file system tags a
# path, because Dir.glob tags a path with the pattern's encoding, and a program
# given with -e has the encoding of the locale's code page on Windows, which
# the C locale doesn't change.
class StackCLocaleProcessTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  def test_a_file_with_a_letter_outside_ascii_in_its_name_is_found_loading_under_the_c_locale
    Dir.mktmpdir do |folder|
      file = File.join(File.realpath(folder), "café.rb")
      File.write(file, "Thread.current[:found] = Stryker::Runtime::Stack.loading?(Thread.current[:paths])\n")
      program = "require 'stryker/runtime'\npattern = #{File.join(folder, '*.rb').inspect}\n" \
        "file = Dir.glob(pattern.dup.force_encoding(Encoding.find('filesystem'))).first\n" \
        "Thread.current[:paths] = Set[Stryker::Runtime::PathKey.of(File.realpath(file))]\n" \
        "load(file)\np Thread.current[:found]"

      assert_equal("true\n", run_program(program, { LC_ALL: "C", LANG: "C" }).first)
    end
  end

  # A path of ASCII bytes finds its UTF-8 key whatever its tag, so the check has
  # no reason to copy and retag it. The spy records the calls that have no
  # separator, which are the ones made only because of the tag: on Windows the
  # check calls PathKey.of for every path, for its separators.
  def test_a_file_with_only_letters_of_ascii_in_its_name_is_found_loading_under_the_c_locale_with_no_path_retagged
    Dir.mktmpdir do |folder|
      file = File.join(File.realpath(folder), "invoice.rb")
      File.write(file, "Thread.current[:found] = Stryker::Runtime::Stack.loading?(Thread.current[:paths])\n")
      program = "require 'stryker/runtime'\nfile = Dir.glob(#{File.join(folder, '*.rb').inspect}).first\n" \
        "Thread.current[:paths] = Set[Stryker::Runtime::PathKey.of(File.realpath(file))]\ntagged = []\n" \
        "Stryker::Runtime::PathKey.singleton_class.prepend(Module.new do\n  " \
        "define_method(:of) { |*args| tagged << args if args.last.nil?; super(*args) }\nend)\n" \
        "load(file)\np [Thread.current[:found], tagged]"

      assert_equal("[true, []]\n", run_program(program, { LC_ALL: "C", LANG: "C" }).first)
    end
  end
end
