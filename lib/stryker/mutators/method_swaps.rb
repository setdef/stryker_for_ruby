# frozen_string_literal: true

module Stryker
  module Mutators
    module MethodSwaps
      BOTH_WAYS = [
        %i[first last],
        %i[min max],
        %i[min_by max_by],
        %i[start_with? end_with?],
        %i[upcase downcase],
        %i[upcase! downcase!],
        %i[lstrip rstrip],
        %i[lstrip! rstrip!],
        %i[ljust rjust],
        %i[sub gsub],
        %i[sub! gsub!],
        %i[all? any?],
        %i[take drop],
        %i[take_while drop_while],
        %i[index rindex],
        %i[push unshift],
        %i[pop shift],
        %i[ceil floor],
        %i[even? odd?],
        %i[positive? negative?],
      ].freeze
      private_constant(:BOTH_WAYS)

      ONE_WAY = { select: :reject, filter: :reject, select!: :reject!, reject: :select, reject!: :select! }.freeze
      private_constant(:ONE_WAY)

      PAIRS = BOTH_WAYS.to_h.merge(BOTH_WAYS.to_h { |left, right| [right, left] }, ONE_WAY).freeze
      private_constant(:PAIRS)

      def self.for(name)
        PAIRS[name]
      end
    end
  end
end
