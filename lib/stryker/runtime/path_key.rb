# frozen_string_literal: true

module Stryker
  module Runtime
    module PathKey
      def self.of(path, separator = File::ALT_SEPARATOR)
        # Ruby on Windows can give the same file with a different drive
        # letter, letter case, or separator. Elsewhere a path is compared as
        # it is, because a case-sensitive file system has files that differ
        # only in case.
        separator ? path.tr(separator, "/").downcase : path
      end
    end
  end
end
