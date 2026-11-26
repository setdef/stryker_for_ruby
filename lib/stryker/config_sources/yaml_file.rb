# frozen_string_literal: true

require "English"
require "psych"
require_relative("text_file")

module Stryker
  module ConfigSources
    class YamlFile < TextFile
      PLAIN_VALUES = "strings, numbers, booleans, null, lists, and maps"
      private_constant(:PLAIN_VALUES)

      private def parse(text)
        # safe_load's defaults allow only plain values, and no aliases.
        Psych.safe_load(text) || {}
      rescue Psych::SyntaxError
        # Psych names the file "<unknown>" when it is given no file name.
        raise(invalid("isn't valid YAML: #{$ERROR_INFO.to_s.delete_prefix('(<unknown>): ')}"))
      rescue Psych::Exception
        raise(invalid("uses more than YAML's plain values (#{PLAIN_VALUES}): #{$ERROR_INFO}"))
      end
    end
  end
end
