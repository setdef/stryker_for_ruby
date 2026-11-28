# frozen_string_literal: true

require_relative("checks/given_twice")
require_relative("checks/not_utf8_values")
require_relative("checks/nul_in_patterns")
require_relative("checks/outside_patterns")
require_relative("checks/threshold_order")
require_relative("checks/unknown_mutators")
require_relative("checks/unknown_option")
require_relative("checks/wrong_type")
require_relative("settings")

module Stryker
  class Configure
    class Problems
      def initialize(settings, root)
        @settings = settings
        @root = root
      end

      def to_a
        @settings.flat_map { |setting| about(setting) } + among_settings
      end

      private def among_settings
        repeated = Settings.repeated(@settings).flat_map { |group| Checks::GivenTwice.new(group).to_a }
        repeated + Checks::ThresholdOrder.new(Settings.merge(@settings)).to_a
      end

      private def about(setting)
        checks = [
          Checks::UnknownOption.new(setting),
          Checks::WrongType.new(setting),
          Checks::NulInPatterns.new(setting),
          Checks::NotUtf8Values.new(setting),
          Checks::OutsidePatterns.new(setting, @root),
          Checks::UnknownMutators.new(setting),
        ]
        checks.lazy.map(&:to_a).find(&:any?) || []
      end
    end
  end
end
