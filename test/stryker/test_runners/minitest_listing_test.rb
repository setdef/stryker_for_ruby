# frozen_string_literal: true

require_relative("../../support/minitest_project")

# How the Minitest adapter loads a project's tests and names them, with
# small projects loaded into this process. Each project's classes have names
# of their own, because every class stays defined here.
class MinitestListingTest < Minitest::Test
  include MinitestProject

  SPEC = { "test/sprocket_spec_test.rb": <<~RUBY }.freeze
    require "minitest/spec"

    describe "Sprocket" do
      it("turns") { _(1).must_equal(1) }
    end
  RUBY
  TWICE = { "test/twice_test.rb": <<~RUBY }.freeze
    require "minitest/spec"

    describe("Twice") { it("works") { pass } }
    describe("Twice") { it("works") { pass } }
  RUBY
  NAMELESS = { "test/nameless_test.rb": "Class.new(Minitest::Test) { def test_nameless = pass }\n" }.freeze
  LISTED = { "test/listed_test.rb": "class ListedTest < Minitest::Test; def test_listed = pass; end\n" }.freeze
  WHERE = { "test/where_test.rb": "class WhereTest < Minitest::Test; def test_here = pass; end\n" }.freeze
  SOURCELESS = { "test/sourceless_test.rb": <<~RUBY }.freeze
    class SourcelessTest < Minitest::Test
      define_method(:test_hash, Kernel.instance_method(:hash))
    end
  RUBY
  HELPED = {
    "test/test_helper.rb": "Stryker::Testing::SampleRuns.ran(:helper)\n",
    "test/a_test.rb": <<~RUBY,
      Stryker::Testing::SampleRuns.ran(:a)

      class HelperFirstTest < Minitest::Test
        def test_a = pass
      end
    RUBY
    "test/b_test.rb": <<~RUBY,
      require "test_helper"
      require_relative "test_helper"
      Stryker::Testing::SampleRuns.ran(:b)
    RUBY
  }.freeze
  ELSEWHERE = {
    "spec/unit/thing_check.rb": <<~RUBY,
      require "thing_support"

      class ThingCheckTest < Minitest::Test
        def test_t = pass
      end
    RUBY
    "support/thing_support.rb": "THING_SUPPORT = true\n",
  }.freeze
  LAZY = { "test/lazy_test.rb": "class LazyLoadTest < Minitest::Test; def test_l = pass; end\n" }.freeze
  SEEDLESS = { "test/seed_set_test.rb": "class SeedSetTest < Minitest::Test; end\n" }.freeze
  SEEDED = { "test/seed_kept_test.rb": "class SeedKeptTest < Minitest::Test; end\n" }.freeze
  private_constant(:ELSEWHERE, :HELPED, :LAZY, :LISTED, :NAMELESS, :SEEDED, :SEEDLESS)
  private_constant(:SOURCELESS, :SPEC, :TWICE, :WHERE)

  def test_a_spec_test_has_its_describe_block_and_its_method_in_its_id
    runner = loaded(SPEC)

    refute_nil(listed(runner, "Sprocket#test_0001_turns"))
    assert_equal("passed", run_ids(runner, "Sprocket#test_0001_turns").first.status)
  end

  def test_two_tests_with_the_same_id_raise_naming_the_id
    error = assert_raises(Stryker::UnsupportedError) { loaded(TWICE) }

    assert_includes(error.message, '"Twice#test_0001_works"')
  end

  def test_a_test_class_with_no_name_raises_naming_its_tests
    error = assert_raises(Stryker::UnsupportedError) { loaded(NAMELESS) }

    assert_includes(error.message, "test_nameless")
  end

  def test_load_tests_takes_the_classes_out_of_minitests_list
    loaded(LISTED)

    refute_includes(Minitest::Runnable.runnables, ListedTest)
  end

  def test_each_test_names_its_file_from_the_projects_root_and_has_no_location
    expected = Stryker::Test.new(
      id: "WhereTest#test_here", name: "test_here", file: "test/where_test.rb", location: nil
    )

    assert_equal(expected, listed(loaded(WHERE), "WhereTest#test_here"))
  end

  def test_a_test_method_that_ruby_gives_no_source_for_has_no_file
    assert_nil(listed(loaded(SOURCELESS), "SourcelessTest#test_hash").file)
  end

  def test_the_helper_loads_before_the_test_files_and_once
    Stryker::Testing::SampleRuns.take
    runner = loaded(HELPED)

    refute_nil(listed(runner, "HelperFirstTest#test_a"))
    assert_equal(%i[helper a b], Stryker::Testing::SampleRuns.take)
  end

  def test_files_and_libs_choose_what_loads_from_where
    runner = loaded(ELSEWHERE, files: ["spec/**/*_check.rb"], libs: ["support"])

    refute_nil(listed(runner, "ThingCheckTest#test_t"))
  end

  def test_run_loads_the_tests_when_load_tests_never_did
    runner = Stryker::TestRunners::MinitestRunner.new(minitest_project(LAZY))

    assert_equal(%w[passed], run_ids(runner, "LazyLoadTest#test_l").map(&:status))
  end

  def test_minitests_seed_is_kept_when_the_project_set_one_and_fixed_when_none_did
    seed = Minitest.seed
    loaded(SEEDED)

    assert_equal(seed, Minitest.seed)
    Minitest.seed = nil
    loaded(SEEDLESS)

    assert_equal(0, Minitest.seed)
  ensure
    Minitest.seed = seed
  end
end
