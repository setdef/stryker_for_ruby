# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/runtime"
require "tmpdir"

# Checks how the hit recorder tells a hit made while a file loads inside a
# test, which is static, from a hit that the test makes. The files that load
# here record through Thread.current[:stryker_recorder], which each test sets
# to a recorder of its own, and keep a block for later in
# Thread.current[:stryker_later].
class StaticHitsTest < Minitest::Test
  def recorder
    @recorder ||= Stryker::Runtime::Recorder.new
  end

  def folders
    @folders ||= []
  end

  def setup
    Thread.current[:stryker_recorder] = recorder
    recorder.test_started(:first)
  end

  def teardown
    Thread.current[:stryker_recorder] = nil
    Thread.current[:stryker_later] = nil
    folders.each { |folder| FileUtils.remove_entry(folder) }
  end

  # The path of a file in a new folder that holds +source+. On macOS the path
  # holds a symbolic link, /var, which a loaded file's frames show resolved.
  def file(source)
    folder = Dir.mktmpdir
    folders << folder
    path = File.join(folder, "invoice.rb")
    File.write(path, source)
    path
  end

  # Code that records the hit +ids+.
  def hit(*ids)
    "Thread.current[:stryker_recorder].record(#{ids})"
  end

  # Loads the file at +path+, after recording that its load began, as the
  # loader's hook does.
  def load_recorded(path)
    recorder.load_began(path)
    load(path)
  end

  def later
    Thread.current[:stryker_later].call
  end

  def buckets
    [recorder.static, recorder.tests[:first]]
  end

  def test_a_hit_at_the_top_level_of_the_file_is_static
    load_recorded(file(hit(5)))

    assert_equal([Set[5], Set.new], buckets)
  end

  def test_a_hit_in_a_class_body_or_a_block_while_the_file_loads_is_static
    load_recorded(file("Class.new { #{hit(5)} }\n[1].each { #{hit(6)} }\n"))

    assert_equal([Set[5, 6], Set.new], buckets)
  end

  def test_a_hit_from_a_block_of_the_file_run_after_its_load_is_the_tests
    load_recorded(file("Thread.current[:stryker_later] = -> { [1].each { #{hit(5)} } }\n"))
    later

    assert_equal([Set.new, Set[5]], buckets)
  end

  def test_a_hit_deep_below_the_top_level_frame_is_static
    load_recorded(file("down = ->(depth) { depth.zero? ? #{hit(5)} : down.call(depth - 1) }\ndown.call(400)\n"))

    assert_equal([Set[5], Set.new], buckets)
  end

  def test_a_hit_in_a_file_that_the_hook_compiled_is_static
    path = file(hit(5))
    recorder.load_began(path)
    RubyVM::InstructionSequence.compile(File.read(path), path, path).eval

    assert_equal([Set[5], Set.new], buckets)
  end

  def test_a_hit_in_a_file_that_bootsnap_compiled_is_static
    path = file(hit(5))
    recorder.load_began(path)
    RubyVM::InstructionSequence.compile_file(path).eval

    assert_equal([Set[5], Set.new], buckets)
  end

  def test_a_hit_in_a_file_loaded_by_a_path_that_is_not_its_real_path_is_static
    path = file(hit(5))
    folder = File.dirname(path)
    load_recorded(File.join(folder, "..", File.basename(folder), "invoice.rb"))

    assert_equal([Set[5], Set.new], buckets)
  end

  def test_a_load_of_a_path_with_no_file_is_recorded_as_given
    recorder.load_began("/app/lib/invoice.rb")

    assert_equal(Set["/app/lib/invoice.rb"], recorder.loaded)
  end

  def test_a_hit_in_a_file_whose_load_was_not_recorded_is_the_tests
    load(file(hit(5)))

    assert_equal([Set.new, Set[5]], buckets)
  end

  # The first file to load makes the recorder check the test's own hit, so
  # the hit from the second file needs a check of its own.
  def test_a_mutant_the_test_reached_first_is_static_when_a_file_reaches_it_while_loading
    load_recorded(file(""))
    recorder.record([5])
    load_recorded(file(hit(5)))

    assert_equal([Set[5], Set[5]], buckets)
  end

  def test_a_test_that_loads_no_file_makes_no_stack_check
    Stryker::Runtime::Stack.stub(:loading?, -> (_paths) { flunk("The recorder checked the stack.") }) do
      recorder.record([5])
    end

    assert_equal([Set.new, Set[5]], buckets)
  end

  # The file keeps a block when it first loads, and calls the block when it
  # loads again. Its second load isn't recorded, so the block's hit then is
  # static only if the recorder checks the stack again.
  def test_only_the_first_hit_of_a_mutant_after_a_load_is_checked
    keep = "Thread.current[:stryker_later] = -> { #{hit(5)} }"
    path = file("Thread.current[:stryker_later] ? Thread.current[:stryker_later].call : #{keep}\n")
    load_recorded(path)
    later
    load(path)

    assert_equal([Set.new, Set[5]], buckets)
  end
end
