# frozen_string_literal: true

require "English"

module Stryker
  class CLI
    module Rescued
      private def rescued
        _ = $ERROR_INFO
      end
    end
  end
end
