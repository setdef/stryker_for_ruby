#!/usr/bin/env bash
# release.yml's steps, described at the top of that file. Each step is one
# argument, and the workflow's jobs call them in this order:
#
#   plan     picks the commit and the version, and says whether this run
#            publishes. Writes commit=, version=, tag=, and publish= to
#            GITHUB_OUTPUT. Needs TAG (empty for a dry run) and, optionally,
#            COMMIT; GITHUB_REF says where the run was started. A TAG that
#            exists is released when it points at the commit, and ends the run
#            when it points anywhere else.
#   build    builds stryker_for_ruby-VERSION.gem from COMMIT with VERSION
#            written into its version file, and its SHA256SUMS, in
#            RELEASE_DIR (release/), and the notes in RELEASE_NOTES
#            (release-notes.md). Needs COMMIT and VERSION.
#   publish  creates the GitHub release of TAG at COMMIT from RELEASE_DIR
#            and RELEASE_NOTES, making the tag when it doesn't exist and
#            using it when it points at COMMIT. Ends the run when TAG points
#            anywhere else. Needs TAG, COMMIT, and VERSION.
#   record   writes the release into trunk's CHANGELOG.md, with its link
#            references, and version file, as one commit pushed to trunk.
#            Needs VERSION and COMMIT.
#
# The steps' decisions are made by tasks/release_command.rb, which this script
# loads from RELEASE_TASKS (the tasks folder of the checkout the workflow runs
# from) so that an old commit being released never brings its own copy. GH_TOKEN
# is the token gh and the task use. RELEASE_PUSH_TOKEN is the token record pushes
# trunk with.
set -euo pipefail

tasks=${RELEASE_TASKS:-$PWD/tasks}
output=${GITHUB_OUTPUT:-/dev/null}
summary=${GITHUB_STEP_SUMMARY:-/dev/null}
server=${GITHUB_SERVER_URL:-https://github.com}
repository=${GITHUB_REPOSITORY:-setdef/stryker_for_ruby}
export GITHUB_REPOSITORY=$repository
bot=(-c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com")

release() {
  ruby -r "$tasks/release_command" -e 'ReleaseCommand.main(ARGV)' "$@"
}

plan() {
  local tag=${TAG:-} requested=${COMMIT:-} commit version publish=false
  mkdir -p tmp
  git fetch --quiet --tags origin trunk
  git rev-list --max-count=300 FETCH_HEAD >tmp/release-commits.txt
  if [ -n "$requested" ]; then
    requested=$(git rev-parse --verify "$requested^{commit}")
  fi
  commit=$(release commit tmp/release-commits.txt ${requested:+"$requested"})
  if [ -n "$tag" ]; then
    version=$(release version "$tag" "$commit")
    # A release GitHub holds without its tag would be published a second time.
    if gh release view "$tag" >/dev/null 2>&1; then
      echo "::error::GitHub has a release $tag already"
      exit 1
    fi
    [ "${GITHUB_REF:-}" = refs/heads/trunk ] && publish=true
  else
    version=$(release version)
    tag=v$version
  fi
  {
    echo "commit=$commit"
    echo "version=$version"
    echo "tag=$tag"
    echo "publish=$publish"
  } >>"$output"
  if [ "$publish" = true ]; then
    echo "Releasing $tag from $commit." | tee -a "$summary"
  else
    echo "A dry run: it would release $tag from $commit, and publishes nothing." | tee -a "$summary"
  fi
}

build() {
  : "${COMMIT:?COMMIT is not set}" "${VERSION:?VERSION is not set}"
  local dir=$PWD/${RELEASE_DIR:-release} notes=$PWD/${RELEASE_NOTES:-release-notes.md} source
  rm -rf "$dir"
  mkdir -p "$dir"
  # The commit's own tree, apart from the checkout the workflow's files are in.
  source=$(mktemp -d)
  git worktree add --quiet --detach "$source" "$COMMIT"
  (
    cd "$source"
    release stamp "$VERSION"
    gem build stryker_for_ruby.gemspec --output "$dir/stryker_for_ruby-$VERSION.gem"
    release notes "$COMMIT" "$notes"
  )
  release assets "$dir" "$VERSION"
  git worktree remove --force "$source"
  echo "Built stryker_for_ruby-$VERSION.gem from $COMMIT." | tee -a "$summary"
}

publish() {
  : "${TAG:?TAG is not set}" "${COMMIT:?COMMIT is not set}" "${VERSION:?VERSION is not set}"
  local dir=${RELEASE_DIR:-release} notes=${RELEASE_NOTES:-release-notes.md} tagged
  # A tag never moves, so a release of one that exists is made only where it
  # points. An annotated tag is listed twice, and its ^{} line is its commit.
  tagged=$(git ls-remote --tags origin "refs/tags/$TAG" "refs/tags/$TAG^{}" | awk 'END { print $1 }')
  if [ -n "$tagged" ] && [ "$tagged" != "$COMMIT" ]; then
    echo "::error::$TAG exists already, at $tagged, not $COMMIT"
    exit 1
  fi
  gh release create "$TAG" --repo "$repository" --target "$COMMIT" \
    --title "Stryker (for Ruby) $VERSION" --notes-file "$notes" "$dir"/*
  echo "Released $TAG from $COMMIT." | tee -a "$summary"
}

record() {
  : "${COMMIT:?COMMIT is not set}" "${VERSION:?VERSION is not set}" "${RELEASE_PUSH_TOKEN:?RELEASE_PUSH_TOKEN is not set}"
  local attempt
  git fetch --quiet --tags origin
  for attempt in 1 2 3; do
    git fetch --quiet origin trunk
    git checkout --quiet --detach FETCH_HEAD
    release record "$VERSION" "$COMMIT"
    if git diff --quiet; then
      echo "Trunk records v$VERSION already." | tee -a "$summary"
      return 0
    fi
    git add --update
    git "${bot[@]}" commit --quiet --file - <<EOF
chore: record v$VERSION in the changelog

v$VERSION was released from $COMMIT, however far trunk has moved since.
Date its changelog section, file under it the entries that commit held, and
raise the version file to match. Entries trunk gained since stay unreleased.
EOF
    if git push --quiet "https://x-access-token:${RELEASE_PUSH_TOKEN}@${server#https://}/$repository" HEAD:refs/heads/trunk; then
      echo "Recorded v$VERSION on trunk as $(git rev-parse HEAD)." | tee -a "$summary"
      return 0
    fi
    echo "trunk moved before the push (attempt $attempt); trying again on top of it"
  done
  echo "::error::trunk moved under every try to record v$VERSION"
  exit 1
}

case "${1:-}" in
plan | build | publish | record) "$1" ;;
*)
  echo "usage: release.sh plan|build|publish|record" >&2
  exit 2
  ;;
esac
