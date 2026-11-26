# frozen_string_literal: true

target :lib do
  # steep/ holds signatures for the parts of gems that ship none, which the
  # gem doesn't publish.
  signature "sig", "steep"
  check "lib"

  configure_code_diagnostics(Steep::Diagnostic::Ruby.all_error)

  library "json"
  library "etc"
  library "open3"
  library "pathname"
  library "fileutils"
  library "minitest"
  library "date"
  library "digest"
  library "timeout"
  library "uri"
  library "stringio"
  library "securerandom"
  library "erb"
  library "etc"
  library "prism"
end

target :tasks do
  signature "tasks/sig"
  check "tasks/ruby_doc_comments.rb"

  configure_code_diagnostics(Steep::Diagnostic::Ruby.all_error)

  library "ripper"
end
