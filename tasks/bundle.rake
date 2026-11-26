# frozen_string_literal: true

namespace :bundle do
  desc "Fail when a frozen install, as CI runs it, would refuse Gemfile.lock"
  task :frozen do
    # An environment hash, not a "NAME=value command" string: Ruby on Windows
    # runs that string as a program named BUNDLE_FROZEN=true. Ruby wants
    # string keys in the hash, which RuboCop's Style/StringHashKeys forbids
    # in a literal.
    env = { BUNDLE_FROZEN: "true" }.transform_keys(&:to_s)
    sh(env, "bundle", "install", "--local")
  end
end
