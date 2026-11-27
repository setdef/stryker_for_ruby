# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/instrumentation/source_file"
require "stryker/instrumenter/parse_pool"
require "stryker/mutators"
require "stryker/source_error"
require "tmpdir"

# Checks what a run does with a project file that doesn't parse.
class SourceFileSyntaxTest < Minitest::Test
  def instrumented(source)
    Dir.mktmpdir("stryker-source-file-") do |root|
      File.binwrite(File.join(root, "broken.rb"), source)
      file = Stryker::Instrumentation::SourceFile.new(root, "broken.rb", 1)
      Stryker::Instrumenter::ParsePool.open(1) { |pool| file.instrumented(pool, Stryker::Mutators::ALL, Stryker::Mutators::Policy.new) }
    end
  end

  def test_a_file_that_does_not_parse_is_the_projects_to_fix_and_names_the_file_and_the_line_of_its_first_error
    error = assert_raises(Stryker::SourceError) { instrumented("a = 1\nb = (2 +\n") }

    assert_includes(error.message, "broken.rb doesn't parse as Ruby #{RUBY_VERSION}: unexpected end-of-input")
    assert_includes(error.message, ", on line 2. ")
  end

  def test_the_message_says_what_to_do_about_it
    error = assert_raises(Stryker::SourceError) { instrumented("def\n") }

    assert_includes(error.message, "Fix the file, or leave it out of the mutate option.")
  end

  def test_only_the_first_error_is_given
    error = assert_raises(Stryker::SourceError) { instrumented("def\nend end end\n") }

    assert_equal(1, error.message.scan(", on line").size)
  end
end
