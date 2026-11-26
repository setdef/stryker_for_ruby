# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/runtime"
require "tmpdir"

# What the tests of static hits share. The files that load in them record
# through Thread.current[:stryker_recorder], which each test sets to a
# recorder of its own, and keep a block for later in
# Thread.current[:stryker_later].
class StaticHitsCase < Minitest::Test
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
end
