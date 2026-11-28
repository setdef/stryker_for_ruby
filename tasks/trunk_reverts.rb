# frozen_string_literal: true

# Which of trunk's commits a newer commit has reverted.
#
# The build cop reads it to tell whether a red run on trunk is settled: the
# commit the run blamed has been reverted. The cop keeps no state, so it can't
# say which commit a run blamed, and takes any commit that the run covers.
class TrunkReverts
  # +commits+ are trunk's, newest first, and +pairs+ are pairs of a commit and
  # the commit it reverts. A revert that a later commit reverted brings its
  # commit back, so it is no revert. A reverting commit that is not among
  # +commits+ is older than all of them, since +commits+ are trunk's newest, and
  # reverts a commit older still, so it counts for nothing.
  def initialize(commits, pairs)
    @commits = commits
    undone = pairs.map(&:last)
    live = pairs.reject { |pair| undone.include?(pair.first) }
    @newest = live.group_by(&:last)
      .transform_values { |reverts| newest(reverts) }
      .compact
  end

  # Whether a commit that a red run covers, from the run's commit at +index+
  # back to the one before the green commit at +good+, was reverted by a
  # commit newer than the run's.
  def settled?(index, good)
    (index...good).any? { |at| @newest.fetch(@commits[at], Float::INFINITY) < index }
  end

  private def newest(reverts)
    reverts.filter_map { |pair| @commits.index(pair.first) }
      .min
  end
end
