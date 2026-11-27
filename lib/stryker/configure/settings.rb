# frozen_string_literal: true

require_relative("../config")
require_relative("../config_sources")
require_relative("default_origin")
require_relative("origin")
require_relative("setting")

module Stryker
  class Configure
    module Settings
      def self.from_file(options, origin, parents = [])
        options.flat_map do |key, value|
          keys = [*parents, key]
          name = keys.join(".")
          if value.is_a?(Hash) && !Config::OPTIONS.key?(name)
            from_file(value, origin, keys)
          else
            [Setting.new(name, value, origin, keys)]
          end
        end
      end

      def self.from_project(root, file)
        located = ConfigSources.locate(root, file)
        located ? from_file(located.source.read || {}, Origin.new(located.label)) : []
      end

      def self.from_flags(options)
        options.map { |name, value| Setting.new(name.to_s, value, Origin.flags) }
      end

      def self.merge(settings)
        settings.to_h { |setting| [setting.name, setting] }
      end

      def self.repeated(settings)
        groups = settings.group_by { |setting| [setting.name, setting.origin] }
        groups.values.select { |group| group.size > 1 }
      end

      def self.effective(merged, name)
        merged[name] || Setting.new(name, Config::DEFAULTS[Config::OPTIONS[name]], DefaultOrigin.instance)
      end
    end
  end
end
