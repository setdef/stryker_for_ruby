# frozen_string_literal: true

require_relative("../../support/minitest_project")

# What the Minitest adapter does in a project process of its own: one that
# requires minitest/autorun and exits normally, and one that loads Minitest
# only when the project does.
class MinitestProcessTest < Minitest::Test
  include MinitestProject

  parallelize_me!

  # A project whose helper requires minitest/autorun, as most do, and whose
  # tests each print a line when they run.
  AUTORUN = {
    "test/test_helper.rb": "require \"minitest/autorun\"\n",
    "test/chosen_test.rb": <<~RUBY,
      require "test_helper"

      class ChosenTest < Minitest::Test
        def test_chosen = puts("ran ChosenTest#test_chosen")
        def test_left_out = puts("ran ChosenTest#test_left_out")
      end
    RUBY
  }.freeze
  ANOTHER = AUTORUN.merge("test/another_test.rb": <<~RUBY).freeze
    require "test_helper"

    class AnotherTest < Minitest::Test
      def test_b = pass
      def test_a = pass
    end
  RUBY
  private_constant(:ANOTHER, :AUTORUN)

  def test_a_process_that_exits_normally_runs_only_the_chosen_test_and_once
    output, = run_program(<<~RUBY, gems: ["minitest"])
      #{ADAPTER}
      runner = Stryker::TestRunners::MinitestRunner.new(#{minitest_project(AUTORUN).inspect})
      runner.load_tests
      runner.run(["ChosenTest#test_chosen"], bail: false, observer: Heard.new)
    RUBY
    expected = %w[started ran finished].map { |event| "#{event} ChosenTest#test_chosen" }
    expected[-1] += " passed"

    assert_equal(expected, output.lines(chomp: true).grep(/ChosenTest/))
  end

  def test_the_adapter_loads_no_minitest_until_the_project_does
    output, = run_program(<<~RUBY, gems: ["minitest"])
      #{ADAPTER}
      puts(defined?(Minitest).inspect)
      Stryker::TestRunners::MinitestRunner.new(#{minitest_project(AUTORUN).inspect}).load_tests
      puts(defined?(Minitest).inspect)
    RUBY

    assert_equal(["nil", '"constant"'], output.lines(chomp: true).first(2))
  end

  def test_a_project_that_never_loads_minitest_raises_name_error
    root = minitest_project("test/plain_test.rb": "PLAIN = true\n")
    output, = run_program(<<~RUBY, gems: ["minitest"])
      #{ADAPTER}
      begin
        Stryker::TestRunners::MinitestRunner.new(#{root.inspect}).load_tests
      rescue NameError => error
        puts(error.name)
      end
    RUBY

    assert_equal("Minitest\n", output)
  end

  def test_two_processes_list_the_same_tests_in_the_same_order
    program = "#{ADAPTER}\nputs(Stryker::TestRunners::MinitestRunner.new(#{minitest_project(ANOTHER).inspect}).load_tests.to_json)\n"
    # The seed changes the order of Minitest's own run, which the at_exit
    # block starts after the list, with no tests left in it.
    first, second = %w[1 2].map { |seed| run_program(program, { SEED: seed }, gems: ["minitest"]).first.lines.first }
    ids = %w[AnotherTest#test_a AnotherTest#test_b ChosenTest#test_chosen ChosenTest#test_left_out]

    assert_equal(first, second)
    assert_equal(ids, JSON.parse(first).map { |test| test["id"] })
  end
end
