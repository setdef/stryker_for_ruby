# frozen_string_literal: true

module Stryker
  module Reporters
    class FileTree
      module Leaves
        def self.shared_folders(leaves)
          # SPDX-SnippetBegin
          # SPDX-License-Identifier: Apache-2.0
          # SPDX-SnippetCopyrightText: Stryker Mutator contributors
          # SPDX-SnippetComment: Ported from determineCommonBasePath in
          # packages/metrics/src/helpers/file.ts of mutation-testing-elements. The port counts the
          # shared folders where the original joins them into a path.
          folders = leaves.map(&:folders)
          shared = (0...(folders.map(&:size).min || 0)).take_while { |depth| same_at?(folders, depth) }
          shared.size
          # SPDX-SnippetEnd
        end

        def self.grouped(leaves)
          # SPDX-SnippetBegin
          # SPDX-License-Identifier: Apache-2.0
          # SPDX-SnippetCopyrightText: Stryker Mutator contributors
          # SPDX-SnippetComment: Ported from toChildModels in packages/metrics/src/calculateMetrics.ts
          # of mutation-testing-elements. The port orders names by byte order where the original uses
          # localeCompare.
          groups = leaves.group_by { |leaf| leaf.names.first.to_s }
          groups.sort_by { |name, group| [file?(group) ? 1 : 0, name] }
          # SPDX-SnippetEnd
        end

        def self.file?(group)
          group.one? && group.all?(&:file?)
        end

        def self.same_at?(folders, depth)
          names = folders.map { |parts| parts[depth] }
          names.uniq.one?
        end
        private_class_method(:same_at?)
      end
    end
  end
end
