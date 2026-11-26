# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/loader_project")

# Checks, in processes of their own, that every instrumented file of a project
# that Zeitwerk loads comes through the loader's hook, whether Zeitwerk
# autoloads it or eager-loads it.
class ZeitwerkTest < Minitest::Test
  include LoaderProject

  parallelize_me!

  FILES = {
    "shop.rb": "module Shop\n  NAME = :original\nend\n",
    "shop/invoice.rb": "module Shop\n  class Invoice\n    TOTAL = :original\n  end\nend\n",
    "shop/receipt.rb": "module Shop\n  class Receipt\n    TOTAL = :original\n  end\nend\n",
  }.freeze
  INSTRUMENTED = FILES.transform_values { |source| source.sub("original", "instrumented") }
  # Sets Zeitwerk up for the project's lib folder, the first on the load path.
  SETUP = <<~RUBY
    require "zeitwerk"
    loader = Zeitwerk::Loader.new
    loader.push_dir($LOAD_PATH.first)
    loader.setup
  RUBY
  # Reads a constant from each file, so Zeitwerk autoloads each.
  AUTOLOAD = <<~RUBY
    p [Shop::NAME, Shop::Invoice::TOTAL, Shop::Receipt::TOTAL]
  RUBY
  # Loads every file before any constant is read.
  EAGER_LOAD = <<~RUBY
    loader.eager_load
    p $LOADED_FEATURES.grep(%r{/lib/shop}).size, Shop::Receipt::TOTAL
  RUBY
  private_constant(:AUTOLOAD, :EAGER_LOAD, :FILES, :INSTRUMENTED, :SETUP)

  # What +program+ prints after the loader is installed and Zeitwerk is set up
  # for the project, and then the loading check.
  def run_installed(program)
    lib, cache = project(FILES, INSTRUMENTED)
    run_program("#{installed(lib, cache)}#{SETUP}#{program}#{CHECK}", gems: ["zeitwerk"]).first
  end

  def test_every_file_zeitwerk_autoloads_comes_through_the_hook
    assert_equal("[:instrumented, :instrumented, :instrumented]\nchecked\n", run_installed(AUTOLOAD))
  end

  def test_every_file_zeitwerk_eager_loads_comes_through_the_hook
    assert_equal("3\n:instrumented\nchecked\n", run_installed(EAGER_LOAD))
  end
end
