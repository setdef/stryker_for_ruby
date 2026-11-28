# frozen_string_literal: true

require_relative("../types")

module Stryker
  class Configure
    module Checks
      class NotUtf8InProcessOptions
        OPTIONS = %w[minitest.testFiles].freeze
        public_constant(:OPTIONS)

        def initialize(setting)
          @setting = setting
        end

        def to_a
          return [] unless OPTIONS.include?(@setting.name)

          Types.strings(@setting.value).filter_map do |pattern|
            next if pattern.dup.force_encoding(Encoding::UTF_8).valid_encoding?

            "#{@setting.mention} has the pattern #{pattern.inspect}, which isn't valid UTF-8, " \
              "and the options of a test runner cross to a project process as JSON."
          end
        end
      end
    end
  end
end
