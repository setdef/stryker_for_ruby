# frozen_string_literal: true

require_relative("config_sources/json_file")
require_relative("config_sources/yaml_file")

module Stryker
  module ConfigSources
    FILE_NAMES = %w[stryker.config.json stryker.config.yml].freeze
    FORMATS = { json: JsonFile, yml: YamlFile, yaml: YamlFile }.freeze
    private_constant(:FORMATS)

    class Located < Data.define(:label, :source)
      # @dynamic label, source
    end
    public_constant(:FILE_NAMES, :Located)

    def self.locate(root, named = nil)
      named ? named_file(root, named) : default_file(root)
    end

    def self.default_file(root)
      existing = FILE_NAMES.select { |name| File.file?(File.expand_path(name, root)) }
      raise(ConfigError, both_exist(existing)) if existing.size > 1

      name, = existing
      source_for(root, name) if name
    end

    def self.both_exist(names)
      "#{names.join(' and ')} both exist, so there is no telling which to read. " \
        "Delete one, or name the one to read: stryker run #{names.first}"
    end

    def self.named_file(root, named)
      unless File.file?(File.expand_path(named, root))
        raise(ConfigError, "The configuration file #{named} doesn't exist.")
      end

      source_for(root, named)
    end

    def self.source_for(root, label)
      format = FORMATS.fetch(File.extname(label).delete_prefix(".").downcase.to_sym) do
        raise(ConfigError, "#{label} isn't a JSON or YAML file. Name a file whose name ends in .json, .yml, or .yaml.")
      end
      Located.new(label:, source: format.new(File.expand_path(label, root), label:))
    end
    private_class_method(:default_file, :both_exist, :named_file, :source_for)
  end
end
