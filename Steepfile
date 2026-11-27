# frozen_string_literal: true

# Steep loads the signatures of both targets into each, so each target needs
# the libraries that every signature names. With fewer, Steep finds no type
# error in the target's files and says nothing of it.
libraries = %w[
  json
  etc
  open3
  pathname
  fileutils
  minitest
  date
  digest
  timeout
  tempfile
  tmpdir
  uri
  stringio
  securerandom
  erb
  prism
  psych
  did_you_mean
  optparse
  net-http
  ripper
]

target :lib do
  # steep/ holds signatures for the parts of gems that ship none, which the
  # gem doesn't publish.
  signature "sig", "steep"
  check "lib"

  configure_code_diagnostics(Steep::Diagnostic::Ruby.all_error)

  libraries.each { |name| library(name) }
end

target :tasks do
  signature "tasks/sig"
  check "tasks/build_cop.rb"
  check "tasks/build_cop_blame.rb"
  check "tasks/build_cop_fast.rb"
  check "tasks/build_cop_step.rb"
  check "tasks/changelog.rb"
  check "tasks/commit_runs.rb"
  check "tasks/github_api.rb"
  check "tasks/github_api"
  check "tasks/release.rb"
  check "tasks/release_assets.rb"
  check "tasks/release_command.rb"
  check "tasks/release_commit.rb"
  check "tasks/trunk_reverts.rb"
  check "tasks/ruby_doc_comments.rb"

  configure_code_diagnostics(Steep::Diagnostic::Ruby.all_error)

  libraries.each { |name| library(name) }
end
