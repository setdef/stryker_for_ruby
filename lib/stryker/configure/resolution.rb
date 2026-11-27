# frozen_string_literal: true

require_relative("../config")
require_relative("../config_error")
require_relative("test_runner_choice")
require_relative("types")

module Stryker
  class Configure
    class Resolution
      MUTATE = %w[
        lib/**/*.rb
        app/**/*.rb
        lib/**/*.erb
        app/**/*.erb
        !**/test/**/*
        !**/spec/**/*
        !**/*_test.rb
        !**/*_spec.rb
      ].freeze
      private_constant(:MUTATE)

      def initialize(settings, root, processors)
        @settings = settings
        @root = root
        @processors = processors
      end

      def config
        values = given
        Config.new(mutate: Types.strings(values.fetch(:mutate, MUTATE)), test_runner: runner(values)).with(
          **values,
          concurrency: concurrency(values[:concurrency])
        )
      end

      private def given
        @settings.to_h { |name, setting| [Config::OPTIONS[name], Types::KINDS[name].convert(setting.value)] }
      end

      private def runner(values)
        String(values.fetch(:test_runner) { TestRunnerChoice.new(@root).name })
      end

      private def concurrency(value)
        case value
        when Integer then value
        when String then [1, ((@processors * Integer(value.delete_suffix("%"), 10)) + 50) / 100].max
        else Config.default_concurrency(@processors)
        end
      end
    end
  end
end
