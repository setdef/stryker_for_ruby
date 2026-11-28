# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/loader_stand_in")
require "json"
require "minitest/mock"
require "stryker/json_value"

# Checks the hook and the loading check for an instrumented file whose name
# isn't valid UTF-8, as a name on Linux may be, which Ruby tags UTF-8 under a
# UTF-8 locale and binary under the C locale.
class LoaderBytesTest < Minitest::Test
  include LoaderStandIn

  BROKEN = "/app/lib/caf\xE9.rb"
  private_constant(:BROKEN)

  # SimpleCov raises, when the suite ends, for a file that Ruby compiled under
  # a path that isn't valid UTF-8, so the stand-in compiles the source under
  # no path.
  def served(&)
    original = RubyVM::InstructionSequence.method(:compile)
    unnamed = -> (source, *_path) { original.call(source) }
    RubyVM::InstructionSequence.stub(:compile, unnamed, &)
  end

  def test_the_hook_serves_the_file_under_either_tag_of_its_path
    install([BROKEN.b])

    assert_equal(["instrumented"] * 2, served { [BROKEN, BROKEN.b].map { |path| loaded(path) } })
  end

  def test_the_hook_leaves_a_file_whose_name_is_valid_utf8_to_ruby_beside_one_that_is_not
    install([BROKEN.b])

    assert_nil(loaded("/app/lib/café.rb"))
  end

  def test_the_check_passes_a_file_the_hook_served_under_either_tag_of_its_path
    install([BROKEN.b])
    served { iseq_class.load_iseq(BROKEN) }

    assert_nil(Stryker::Runtime::Loader.check([BROKEN], iseq_class))
  end

  def test_the_check_lists_a_file_the_hook_did_not_serve_in_a_message_that_a_json_line_holds
    install([BROKEN.b])
    error = assert_raises(Stryker::Runtime::LoadingError) { Stryker::Runtime::Loader.check([BROKEN.b], iseq_class) }
    line = JSON.generate(Stryker::JsonValue.plain({ error: error.message }))

    assert_includes(JSON.parse(line)["error"], "/app/lib/caf")
  end
end
