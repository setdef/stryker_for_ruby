# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/loader_project")

# Checks the loader on RubyVM::InstructionSequence itself, in processes of
# their own, for a file that Ruby reaches through another spelling of its path
# or through a path in another encoding. loader_process_test.rb checks the
# rest of what the loader does there.
class LoaderPathsProcessTest < Minitest::Test
  include LoaderProject

  parallelize_me!

  # On Windows, Ruby gives the hook a path spelled as the load path spells
  # it, so the load path swaps its letters' case there. Elsewhere a file
  # system can tell case apart, and the load path stays as it is.
  def test_a_file_found_through_another_spelling_of_its_folder_is_instrumented
    lib, cache = project(FILES, INSTRUMENTED)
    spelled = File::ALT_SEPARATOR ? lib.swapcase.tr("/", File::ALT_SEPARATOR) : lib
    program = "#{installed(spelled, cache)}require 'invoice'\np TOTAL\n#{CHECK}"

    assert_equal(":instrumented\nchecked\n", run_program(program).first)
  end

  # Another spelling of the folder at +lib+ that Ruby doesn't resolve for a
  # require of an absolute path: the folder's letters in the other case on
  # Windows, which can't make a symbolic link without the rights to, and a
  # symbolic link elsewhere.
  def spelling(lib)
    return lib.swapcase.tr("/", File::ALT_SEPARATOR) if File::ALT_SEPARATOR

    File.join(folder, "alias").tap { |link| File.symlink(lib, link) }
  end

  # The path of +file+ in lib through another spelling of lib.
  def aliased(lib, file)
    File.join(spelling(lib), file)
  end

  # A file that the loader serves shows the same __dir__ as a file that plain
  # Ruby loads through the same spelling of its folder. The file that isn't
  # instrumented stands for plain Ruby.
  def test_a_file_required_through_another_spelling_of_its_folder_has_the_dir_that_plain_ruby_gives
    lib, cache = project({ "folder.rb": "DIR = :original\n", "plain.rb": "PLAIN = __dir__\n" }, {})
    file = aliased(lib, "folder.rb")
    Stryker::Runtime::Cache.write(cache, { file => "DIR = __dir__\n" })
    program = "#{installed(lib, cache)}require #{file.inspect}\nrequire #{aliased(lib, 'plain.rb').inspect}\n" \
      "p DIR == PLAIN"

    assert_equal("true\n", run_program(program).first)
  end

  # A load adds nothing to $LOADED_FEATURES, so the loading check can't see
  # that the hook missed it.
  def test_a_file_loaded_through_another_spelling_of_its_folder_is_instrumented
    lib, cache = project(FILES, INSTRUMENTED)
    program = "#{installed(lib, cache)}load(#{aliased(lib, 'line.rb').inspect})\np LINE\n#{CHECK}"

    assert_equal(":instrumented\nchecked\n", run_program(program).first)
  end

  def test_a_file_required_through_another_spelling_of_its_folder_is_instrumented
    lib, cache = project(FILES, INSTRUMENTED)
    program = "#{installed(lib, cache)}require #{aliased(lib, 'line.rb').inspect}\np LINE\n#{CHECK}"

    assert_equal(":instrumented\nchecked\n", run_program(program).first)
  end

  # Ruby gives the hook a path that a load finds in the working directory as
  # it was written, relative, and a load adds nothing to $LOADED_FEATURES, so
  # the loading check can't see that the hook missed it.
  def test_a_file_loaded_by_a_path_relative_to_the_working_directory_is_instrumented
    lib, cache = project(FILES, INSTRUMENTED)
    program = "require 'stryker/runtime'\nStryker::Runtime::Loader.install(#{cache.inspect})\n" \
      "Dir.chdir(#{lib.inspect})\nload 'line.rb'\np LINE\n#{CHECK}"

    assert_equal(":instrumented\nchecked\n", run_program(program).first)
  end

  def test_a_file_loaded_by_a_path_relative_to_the_working_directory_has_the_dir_that_plain_ruby_gives
    lib, cache = project({ "folder.rb": "DIR = :original\n", "plain.rb": "PLAIN = __dir__\n" }, {})
    Stryker::Runtime::Cache.write(cache, { File.join(lib, "folder.rb") => "DIR = __dir__\n" })
    program = "require 'stryker/runtime'\nStryker::Runtime::Loader.install(#{cache.inspect})\n" \
      "Dir.chdir(#{lib.inspect})\nload 'folder.rb'\nload 'plain.rb'\np DIR == PLAIN"

    assert_equal("true\n", run_program(program).first)
  end

  # The stack check compares the recorded path with the absolute path of each
  # frame, so a path as written, relative, never matches.
  def test_a_hit_in_a_file_first_loaded_inside_a_test_by_a_path_relative_to_the_working_directory_is_static
    lib, cache = project(FILES, { "line.rb": "Stryker::Active.hit(5)\nLINE = :instrumented\n" })
    program = "require 'stryker/runtime'\nStryker::Runtime::Loader.install(#{cache.inspect})\n" \
      "Dir.chdir(#{lib.inspect})\nStryker::Runtime::RECORDER.test_started(:first)\nload 'line.rb'\n" \
      "p [Stryker::Runtime::RECORDER.static, Stryker::Runtime::RECORDER.tests[:first]]"

    assert_equal("[Set[5], Set[]]\n", run_program(program).first)
  end

  # A program that Ruby starts with the C locale reads each path from the file
  # system as bytes tagged US-ASCII, where the cache holds the same bytes
  # tagged UTF-8, so a project in a folder with a letter outside ASCII, such
  # as a user's name, is the case. Nothing in the program's text is outside
  # ASCII.
  def test_a_file_in_a_folder_with_a_letter_outside_ascii_is_instrumented_under_the_c_locale
    lib, cache = project({}, { "café/line.rb": "LINE = :instrumented\n" })
    FileUtils.mkdir_p(File.join(lib, "caf\u00e9"))
    File.write(File.join(lib, "caf\u00e9", "line.rb"), "LINE = :original\n")
    program = "#{installed(lib, cache)}folder = File.join(#{lib.inspect}, Dir.children(#{lib.inspect}).first)\n" \
      "require File.join(folder, 'line.rb')\np LINE\n#{CHECK}"

    assert_equal(":instrumented\nchecked\n", run_program(program, { LC_ALL: "C", LANG: "C" }).first)
  end
end
