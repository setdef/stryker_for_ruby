# frozen_string_literal: true

require_relative("../test_helper")
require "minitest/mock"
require "stringio"
require "stryker/config"
require "stryker/instrumentation"

# Checks the stages that instrument a file whose name holds bytes that aren't
# valid UTF-8, as a name on Linux may. Only Linux can make such a file, so
# File.binread gives its source.
class InstrumentationBytesTest < Minitest::Test
  BROKEN = "lib/caf\xE9.rb".b
  SOURCE = -> (_path) { +"def on = true\n" }
  private_constant(:BROKEN, :SOURCE)

  def instrumented(root, paths)
    config = Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", concurrency: 1)
    mutators = [Stryker::Mutators::BooleanLiteral]
    File.stub(:binread, SOURCE) { Stryker::Instrumentation.new(root, config, mutators, warnings: StringIO.new).call(paths) }
  end

  def test_a_file_is_found_by_its_absolute_path_as_bytes_whatever_the_letters_of_the_root
    result = instrumented("/rööt", [BROKEN])

    assert_equal(["/rööt/".b + BROKEN], result.sources.keys.map(&:b))
  end

  def test_each_mutant_of_such_a_file_names_it_by_the_bytes_of_its_path_from_the_root
    result = instrumented("/rööt", [BROKEN])

    assert_equal(Set[BROKEN], result.mutants.to_set { |mutant| mutant.file.b })
  end
end
