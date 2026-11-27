# frozen_string_literal: true

require_relative("../../support/runtime_process")

# What the fork parent does before it forks a child, in a Ruby process of its
# own, because a hit that a Ractor made lands in that process's recorder. The
# forking is a stand-in that starts a process that ends at once, so the
# program runs on every system.
class ChildrenTest < Minitest::Test
  include RuntimeProcess

  parallelize_me!

  # Makes a hit in a Ractor while the parent loads, and starts a child.
  START = <<~RUBY
    require "rbconfig"
    require "stryker/isolation/children"
    forking = Object.new
    def forking.start(_run, _work) = [Process.spawn(RbConfig.ruby, "-e", "nil"), IO.pipe.first]
    relay = Object.new
    def relay.forked(_run, _pid) = nil
    Ractor.new { Stryker::Active.hit(1) }.value
    children = Stryker::Isolation::Children.new(forking, relay)
    children.start(Struct.new(:timeout_ms).new(30_000), nil)
    children.stop
    p Stryker::Runtime::RECORDER.static.to_a
  RUBY
  private_constant(:START)

  # The child inherits the static bucket, so the hits that the project's
  # Ractors made while the parent loaded are in it before the fork.
  def test_the_hits_of_the_projects_ractors_are_in_the_static_bucket_before_a_child_starts
    assert_equal("[1]\n", run_program(START).first)
  end
end
