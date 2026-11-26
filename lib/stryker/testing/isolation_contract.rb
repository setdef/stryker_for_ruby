# frozen_string_literal: true

require_relative "isolation_contract/cleanup"
require_relative "isolation_contract/crashes"
require_relative "isolation_contract/state"
require_relative "isolation_contract/statuses"

module Stryker
  module Testing
    module IsolationContract
      include Statuses
      include Crashes
      include State
      include Cleanup
    end
  end
end
