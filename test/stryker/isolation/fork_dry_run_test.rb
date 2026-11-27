# frozen_string_literal: true

require_relative("../../test_helper")
require "fileutils"
require "stryker/config"
require "stryker/isolation/fork_per_run"
require "stryker/runtime/cache"
require "tmpdir"

# The dry run through the fork adapter, with a real fork parent and its child,
# in a small Minitest project of its own. Windows has no fork.
class ForkDryRunTest < Minitest::Test
  parallelize_me!

  # Mutant 1 is in a constant's value, so its switch runs while the file
  # loads, in the parent. Mutant 2 is in a method that a test calls.
  LIBRARY = <<~RUBY
    module Shop
      RATE = (::Stryker::Active.id == 1 ? 3 : (::Stryker::Active.hit(1); 2))

      def self.total(price) = (::Stryker::Active.id == 2 ? price : (::Stryker::Active.hit(2); price * RATE))
    end
  RUBY
  HELPER = <<~RUBY
    require "minitest"
    require "shop"
  RUBY
  private_constant(:HELPER, :LIBRARY)

  def setup
    skip("Windows has no fork.") unless Process.respond_to?(:fork)
    @root = Dir.mktmpdir("stryker-dry-run-")
    @cache = Dir.mktmpdir("stryker-cache-")
  end

  def teardown
    [@root, @cache].compact.each { |folder| FileUtils.remove_entry(folder) }
  end

  def write(path, source)
    file = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, source)
    file
  end

  # Writes the project with +tests+ as the body of its one test class.
  def project(tests)
    library = write("lib/shop.rb", LIBRARY)
    Stryker::Runtime::Cache.write(@cache, { library => LIBRARY })
    write("test/test_helper.rb", HELPER)
    write("test/shop_test.rb", "require \"test_helper\"\n\nclass ShopTest < Minitest::Test\n#{tests}\nend\n")
  end

  # Writes the project of +tests+, and runs its dry run with a limit of
  # +minutes+.
  def dry_run(tests, minutes: 5)
    project(tests)
    config = Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", dry_run_timeout_minutes: minutes)
    isolation = Stryker::Isolation::ForkPerRun.new(@cache, @root)
    isolation.start(config)
    begin
      isolation.dry_run(config)
    ensure
      isolation.stop
    end
  end

  def test_the_dry_run_finds_the_static_bucket_of_the_parent_and_each_tests_bucket
    found = dry_run("  def test_total = assert_equal(20, Shop.total(10))\n  def test_rate = assert_equal(2, Shop::RATE)")

    assert_equal([1], found.static_bucket)
    assert_equal([[], [2]], found.buckets.values_at("ShopTest#test_rate", "ShopTest#test_total"))
    assert_equal(%w[passed passed], found.results.map(&:status))
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
