# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/static_hits_case")

# Checks which hits get a stack check after a file begins to load: each
# thread's own, and every mutant at a site.
class StaticHitsChecksTest < StaticHitsCase
  # Another thread reaches the mutant while the file loads, before the file's
  # own top level does. That thread's stack has no top-level frame, so only
  # its own hit is the test's.
  def test_a_hit_on_another_thread_leaves_the_loading_files_hit_static
    on_thread = "recorder = Thread.current[:stryker_recorder]\nThread.new { recorder.record([5]) }.join\n"
    load_recorded(file("#{on_thread}#{hit(5)}\n"))

    assert_equal([Set[5], Set[5]], buckets)
  end

  def test_a_site_with_a_mutant_not_yet_checked_gets_a_stack_check
    load_recorded(file("#{hit(5)}\n#{hit(5, 6)}\n"))

    assert_equal([Set[5, 6], Set.new], buckets)
  end

  # Every mutant at the site the test reached is checked, so the file's later
  # hit of the second one, on a load the hook didn't see, stays the test's.
  def test_every_mutant_at_a_site_is_checked_together
    keep = "Thread.current[:stryker_later] = -> { #{hit(5, 6)} }"
    path = file("Thread.current[:stryker_later] ? #{hit(6)} : #{keep}\n")
    load_recorded(path)
    later
    load(path)

    assert_equal([Set.new, Set[5, 6]], buckets)
  end
end
