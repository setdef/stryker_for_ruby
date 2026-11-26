# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"
require "tmpdir"

# Checks how the stack check compares a frame's path, with a Windows path
# separator passed in, because the suite also runs where there is none. The
# separator Ruby has on the running system is File::ALT_SEPARATOR, nil
# outside Windows. static_hits_test.rb checks the stack check through the
# recorder.
class StackTest < Minitest::Test
  WINDOWS = "\\"
  private_constant(:WINDOWS)

  def folders
    @folders ||= []
  end

  def teardown
    Thread.current[:stryker_paths] = nil
    Thread.current[:stryker_result] = nil
    folders.each { |folder| FileUtils.remove_entry(folder) }
  end

  # The path of a file in a new folder that holds +source+.
  def file(source)
    folder = Dir.mktmpdir
    folders << folder
    path = File.join(folder, "Invoice.rb")
    File.write(path, source)
    path
  end

  # What Stack.loading? answers with +separator+ from the top level of a new
  # file, while it loads, when the paths it checks are the block's value for
  # the file's path.
  def loading_during_load(separator)
    check = "Stryker::Runtime::Stack.loading?(Thread.current[:stryker_paths], #{separator.inspect})"
    path = file("Thread.current[:stryker_result] = #{check}\n")
    Thread.current[:stryker_paths] = Set.new(yield(path))
    load(path)
    Thread.current[:stryker_result]
  end

  def test_a_path_that_differs_in_case_and_separator_is_found_on_windows
    found = loading_during_load(WINDOWS) do |path|
      Stryker::Runtime::PathKey.of_file(File.realpath(path).upcase.tr("/", WINDOWS), WINDOWS)
    end

    assert(found)
  end

  def test_a_path_that_differs_in_separator_is_not_found_with_no_separator
    # The paths are not run through PathKey.of_file, because on Windows
    # File.realpath accepts a backslash path and returns its forward-slash
    # form, which would match.
    found = loading_during_load(nil) { |path| [path.tr("/", WINDOWS)] }

    refute(found)
  end

  def test_a_frame_with_no_path_is_skipped_on_windows
    source = "Stryker::Runtime::Stack.loading?(Set['/app/lib/invoice.rb'], #{WINDOWS.inspect})"

    refute(RubyVM::InstructionSequence.compile(source).eval)
  end
end
