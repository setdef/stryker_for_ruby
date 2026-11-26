# frozen_string_literal: true

require_relative "site"

module Stryker
  class Instrumenter
    class Splice
      def self.merged(sites)
        by_node = sites.group_by { |site| (site.start_offset)...(site.end_offset) }
        by_node.map do |range, group|
          Site.new(start_offset: range.begin, end_offset: range.end, branches: group.flat_map(&:branches).sort_by(&:id))
        end
      end

      def initialize(source, sites)
        @bytes = source.b
        @insertions = Splice.merged(sites).flat_map(&:insertions).sort_by(&:order)
      end

      def output
        offsets = @insertions.map(&:offset)
        ends = [*offsets, @bytes.bytesize]
        gaps = [0, *offsets].each_with_index.map { |offset, index| @bytes.byteslice(offset...(ends[index])).to_s }
        gaps.zip(@insertions.map(&:text)).join.b
      end
    end
  end
end
