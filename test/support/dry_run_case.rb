# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "stryker/config"
require "stryker/mutant_run"
require "stryker/runtime/cache"
require "tmpdir"

# The dry run through an isolation adapter that runs it, with real project
# processes, in a small Minitest project of its own. A test class that
# includes it says which adapter with +dry_run_isolation+.
module DryRunCase
  # Mutant 1 is in a constant's value, so its switch runs while the file
  # loads. Mutant 2 is in a method that a test calls.
  LIBRARY = <<~RUBY
    module Shop
      RATE = (::Stryker::Active.id == 1 ? 3 : (::Stryker::Active.hit(1); 2))

      def self.total(price) = (::Stryker::Active.id == 2 ? price : (::Stryker::Active.hit(2); price * RATE))
    end
  RUBY
  # Notes each load of the tests in the project's file "loads".
  HELPER = <<~RUBY
    require "minitest"
    require "shop"
    File.open(File.join(__dir__, "..", "loads"), "a") { |file| file.puts("loaded") }
  RUBY
  private_constant(:HELPER, :LIBRARY)

  def setup
    super
    @root = Dir.mktmpdir("stryker-dry-run-")
    @cache = Dir.mktmpdir("stryker-cache-")
  end

  def teardown
    [@root, @cache].compact.each { |folder| FileUtils.remove_entry(folder) }
    super
  end

  def write(path, source)
    file = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, source)
    file
  end

  # Writes the project with +tests+ as the body of its one test class, in
  # the file at +path+.
  def project(tests, path = "test/shop_test.rb")
    library = write("lib/shop.rb", LIBRARY)
    Stryker::Runtime::Cache.write(@cache, { library => LIBRARY })
    write("test/test_helper.rb", HELPER)
    write(path, "require \"test_helper\"\n\nclass ShopTest < Minitest::Test\n#{tests}\nend\n")
  end

  # Writes the project of +tests+, and yields the started adapter and the
  # config, with a limit of +minutes+ for the dry run and the options of
  # the config as keywords, until the block ends.
  def started(tests, minutes, path: "test/shop_test.rb", **)
    project(tests, path)
    config = Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", dry_run_timeout_minutes: minutes, **)
    isolation = dry_run_isolation(@cache, @root)
    isolation.start(config)
    begin
      yield(isolation, config)
    ensure
      isolation.stop
    end
  end

  # Writes the project of +tests+, and runs its dry run with a limit of
  # +minutes+.
  def dry_run(tests, minutes: 5, **)
    started(tests, minutes, **) { |isolation, config| isolation.dry_run(config) }
  end

  # Runs the dry run of a project whose one test reaches mutant 2, and then
  # that mutant's run, and gives the run's status and how many times the
  # project's tests loaded.
  def dry_run_and_mutant_run
    statuses = []
    started("  def test_total = assert_equal(20, Shop.total(10))", 5) do |isolation, config|
      isolation.dry_run(config)
      isolation.run_all([runtime_run]) { |result| statuses << result.status }
    end
    [statuses, File.readlines(File.join(@root, "loads")).size]
  end

  def runtime_run
    edit = { start_offset: 0, end_offset: 1, replacement: "price" }
    mutant = Stryker::Mutant.new(id: 2, file: "lib/shop.rb", mutator_name: "ArithmeticOperator", **edit)
    tests = ["ShopTest#test_total"]
    Stryker::MutantRun.new(mutant:, static: false, test_ids: tests, covered_by: tests, timeout_ms: 60_000)
  end

  def test_the_dry_run_finds_the_static_bucket_of_the_load_and_each_tests_bucket
    found = dry_run("  def test_total = assert_equal(20, Shop.total(10))\n  def test_rate = assert_equal(2, Shop::RATE)")

    assert_equal([1], found.static_bucket)
    assert_equal([[], [2]], found.buckets.values_at("ShopTest#test_rate", "ShopTest#test_total"))
    assert_equal(%w[passed passed], found.results.map(&:status))
  end

  PLUGIN_TESTS = "plugins/cart/test/shop_test.rb"
  TOTAL = "  def test_total = assert_equal(20, Shop.total(10))"
  private_constant(:PLUGIN_TESTS, :TOTAL)

  def test_the_dry_run_loads_the_test_files_that_minitest_test_files_names
    found = dry_run(TOTAL, path: PLUGIN_TESTS, minitest_test_files: ["plugins/*/test/*_test.rb"])

    assert_equal(["ShopTest#test_total"], found.results.map { |result| result.test.id })
  end

  def test_the_dry_run_loads_only_the_test_files_that_minitest_test_files_names
    found = dry_run(TOTAL, minitest_test_files: ["plugins/*/test/*_test.rb"])

    assert_empty(found.results)
  end

  def test_a_test_file_outside_the_default_files_is_not_loaded_when_minitest_test_files_is_not_given
    found = dry_run(TOTAL, path: PLUGIN_TESTS)

    assert_empty(found.results)
  end

  def test_a_test_that_fails_with_no_mutant_active_fails_the_dry_run
    error = assert_raises(Stryker::Isolation::DryRunError) { dry_run("  def test_total = assert_equal(25, Shop.total(10))") }

    assert_includes(error.message, "ShopTest#test_total failed")
  end

  def test_a_dry_run_past_its_limit_fails_with_the_option_that_sets_it
    error = assert_raises(Stryker::Isolation::DryRunError) { dry_run("  def test_slow = sleep(30)", minutes: 0.005) }

    assert_includes(error.message, "dryRunTimeoutMinutes")
  end
end
