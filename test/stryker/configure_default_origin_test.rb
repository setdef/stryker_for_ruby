# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/configure/default_origin"

# Checks how a default names an option: as the option is written in a file,
# whichever way the other values were given.
class ConfigureDefaultOriginTest < Minitest::Test
  def test_spells_an_option_as_a_file_does_not_as_a_flag
    assert_equal("timeoutMS", Stryker::Configure::DefaultOrigin.instance.spell("timeoutMS"))
  end

  def test_mentions_an_option_by_default
    assert_equal(%("timeoutMS" by default), Stryker::Configure::DefaultOrigin.instance.mention("timeoutMS"))
  end
end
