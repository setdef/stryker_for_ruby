# frozen_string_literal: true

require_relative("../types")

module Stryker
  class Configure
    module Checks
      class OutsidePatterns
        LEAVE_OUT = { mutate: "!" }.freeze
        private_constant(:LEAVE_OUT)

        def initialize(setting, root)
          @setting = setting
          @root = File.expand_path(root)
        end

        def to_a
          return [] unless Types::PATTERN_LISTS.include?(@setting.name)

          outside = Types.strings(@setting.value).filter { |pattern| outside?(pattern) }
          outside.map do |pattern|
            "#{@setting.mention} has the pattern #{pattern.inspect}, which is outside the project's root."
          end
        end

        private def outside?(pattern)
          path = File.absolute_path(pattern.delete_prefix(LEAVE_OUT.fetch(@setting.name.to_sym, "")), @root)
          path != @root && !path.start_with?(File.join(@root, ""))
        end
      end
    end
  end
end
