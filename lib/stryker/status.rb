# frozen_string_literal: true

module Stryker
  module Status
    def self.check(status, allowed, kind)
      return if allowed.include?(status)

      raise(ArgumentError, "unknown #{kind} status #{status.inspect}, expected one of #{allowed.join(', ')}")
    end
  end
end
