# frozen_string_literal: true

# Which of trunk's commits a newer commit has reverted.
#
# The build cop reads it to tell whether a red run on trunk is settled: the
# commit the run blamed has been reverted. The cop keeps no state, so it can't
# say which commit a run blamed, and takes any commit that the run covers.
class TrunkReverts
  # +commits+ are trunk's, newest first, and +pairs+ are pairs of a commit and
  # the commit it reverts. A revert that a later commit reverted brings its
  # commit back, so it is no revert. Raises ArgumentError for a reverting
  # commit that is not among +commits+.
  def initialize(commits, pairs)
    @commits = commits
    undone = pairs.map(&:last)
    live = pairs.reject { |pair| undone.include?(pair.first) }
    @newest = live.group_by(&:last).transform_values { |reverts| newest(reverts) }
  end

  # Whether a commit that a red run covers, from the run's commit at +index+
  # back to the one before the green commit at +good+, was reverted by a
  # commit newer than the run's.
  def settled?(index, good)
    (index...good).any? { |at| @newest.fetch(@commits[at], Float::INFINITY) < index }
  end

  private def newest(reverts)
    reverts.map { |pair| position(pair.first) }
      .min
  end

  private def position(commit)
    @commits.index(commit) || raise(ArgumentError, "#{commit} reverts a commit but is not among trunk's commits")
  end
end
