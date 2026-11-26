# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/runtime_process")

# Checks the hit recorder through a dry run in a process of its own: hits from
# other Ractors, and a file that first loads inside a test.
class DryRunTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  # Makes hits from other Ractors before, during, and between two tests, and
  # prints the buckets.
  RACTORS = <<~RUBY
    require "stryker/runtime"
    recorder = Stryker::Runtime::RECORDER
    take_value(Ractor.new { Stryker::Active.hit(1) })
    recorder.test_started(:first)
    take_value(Ractor.new { Stryker::Active.hit(2); Stryker::Active.load_began("/app/lib/invoice.rb") })
    recorder.test_finished(:passed)
    take_value(Ractor.new { Stryker::Active.hit(3) })
    recorder.test_started(:second)
    recorder.test_finished(:passed)
    p [recorder.static.to_a.sort, recorder.tests.transform_values(&:to_a), recorder.loaded.to_a]
  RUBY

  # Requires two files inside a test: one that a stand-in for the loader's
  # hook compiles, and one that Ruby compiles. Each sets a constant while it
  # loads, and defines a method that the test then calls.
  FILES = <<~RUBY
    require "stryker/runtime"
    require "tmpdir"
    folder = Dir.mktmpdir
    invoice_path = File.join(folder, "invoice.rb")
    tax_path = File.join(folder, "tax.rb")
    File.write(invoice_path, "RATE = (::Stryker::Active.hit(1); 2)\\ndef total = (::Stryker::Active.hit(2); RATE * 3)\\n")
    File.write(tax_path, "TAX = (::Stryker::Active.hit(3); 1)\\ndef tax = (::Stryker::Active.hit(4); TAX)\\n")
    hook = Module.new do
      define_method(:load_iseq) do |path|
        ::Stryker::Active.load_began(path)
        RubyVM::InstructionSequence.compile(File.read(path), path, path) if path == invoice_path
      end
    end
    RubyVM::InstructionSequence.singleton_class.prepend(hook)
    recorder = Stryker::Runtime::RECORDER
    recorder.test_started(:first)
    require invoice_path
    require tax_path
    total + tax
    recorder.test_finished(:passed)
    p [recorder.static.to_a.sort, recorder.tests[:first].to_a.sort, recorder.loaded.superset?(Set[invoice_path, tax_path])]
  RUBY

  private_constant(:FILES, :RACTORS)

  def test_a_hit_from_another_ractor_lands_in_the_bucket_current_when_it_is_drained
    expected = [[1, 3], { first: [2], second: [] }, ["/app/lib/invoice.rb"]].inspect

    assert_equal("#{expected}\n", run_program(RACTORS).first)
  end

  def test_a_hit_while_a_file_first_loads_inside_a_test_is_static
    assert_equal(["[[1, 3], [2, 4], true]\n", []], run_program(FILES))
  end
end
