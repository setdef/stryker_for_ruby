# frozen_string_literal: true

require "etc"
require_relative("config")
require_relative("config_error")
require_relative("configure/problems")
require_relative("configure/resolution")
require_relative("configure/settings")

module Stryker
  class Configure
    def self.call(options: {}, file: nil, root: Dir.pwd)
      new.call(options:, file:, root:)
    end

    def initialize(processors: Etc.nprocessors)
      @processors = processors
    end

    def call(options: {}, file: nil, root: Dir.pwd)
      settings = Settings.from_project(root, file) + Settings.from_flags(options)
      problems = Problems.new(settings, root).to_a
      raise(ConfigError, problems.join("\n")) unless problems.empty?

      Resolution.new(Settings.merge(settings), root, @processors).config
    end
  end
end
