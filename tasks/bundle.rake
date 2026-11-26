# frozen_string_literal: true

namespace :bundle do
  desc "Fail when a frozen install, as CI runs it, would refuse Gemfile.lock"
  task :frozen do
    sh("BUNDLE_FROZEN=true bundle install --local")
  end
end
