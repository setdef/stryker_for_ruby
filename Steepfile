# frozen_string_literal: true

target :lib do
  signature "sig"
  check "lib"

  configure_code_diagnostics(Steep::Diagnostic::Ruby.all_error)

  library "json"
  library "pathname"
  library "fileutils"
  library "minitest"
  library "date"
  library "timeout"
  library "uri"
  library "stringio"
  library "securerandom"
  library "erb"
end
