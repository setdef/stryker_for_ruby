# frozen_string_literal: true

require_relative("checks/outside_patterns")
require_relative("checks/unknown_mutators")
require_relative("checks/unknown_option")
require_relative("checks/wrong_type")

module Stryker
  class Configure
    class Problems
      def initialize(settings, root)
        @settings = settings
        @root = root
      end

      def to_a
        @settings.flat_map { |setting| about(setting) }
      end

      private def about(setting)
        checks = [
          Checks::UnknownOption.new(setting),
          Checks::WrongType.new(setting),
          Checks::OutsidePatterns.new(setting, @root),
          Checks::UnknownMutators.new(setting),
        ]
        checks.lazy.map(&:to_a).find(&:any?) || []
      end
    end
  end
end
