# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/reporters/project_file"
require "tmpdir"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks how a project file is read and named when its name holds bytes that
# aren't valid UTF-8, as a name on Linux may, under a root that has a letter
# outside ASCII. Only Linux can make such a file, so File.binread stands in.
class ProjectFileBytesTest < Minitest::Test
  include RuntimeProcess

  BROKEN = "lib/caf\xE9.rb".b
  PROGRAM = <<~'RUBY'
    require "stryker/reporters/project_file"
    Dir.chdir(%<folder>s)
    begin
      Stryker::Reporters::ProjectFile.new("", "lib/caf\xE9.rb".b).source
    rescue SystemCallError => error
      puts error.class
    end
  RUBY
  private_constant(:BROKEN, :PROGRAM)

  def test_the_file_is_read_by_the_bytes_of_its_name_under_a_root_with_a_letter_outside_ascii
    read = []
    reader = -> (path) { (read << path) && +"x = 1\n" }
    File.stub(:binread, reader) { Stryker::Reporters::ProjectFile.new("/rööt", BROKEN).source }

    assert_equal(["/rööt/".b + BROKEN], read.map(&:b))
  end

  def test_the_name_keeps_its_bytes_and_is_shown_with_an_escape
    file = Stryker::Reporters::ProjectFile.new("/app", BROKEN)

    assert_equal([BROKEN, 'lib/caf\xE9.rb'], [file.name, file.display_name])
  end

  # The working directory has the tag of the file system, and joins to a name
  # in another tag only when one of them has no letter outside ASCII. A
  # process of its own changes its working directory.
  def test_a_file_under_an_empty_root_in_a_working_directory_with_a_letter_outside_ascii_is_found_by_its_bytes
    Dir.mktmpdir do |parent|
      folder = File.join(parent, "rööt")
      Dir.mkdir(folder)

      assert_equal(["Errno::ENOENT\n", []], run_program(format(PROGRAM, folder: folder.inspect), gems: %w[prism]))
    end
  end
end
