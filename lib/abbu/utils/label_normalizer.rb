# lib/abbu/utils/label_normalizer.rb
# frozen_string_literal: true

module Abbu
  module Utils
    class LabelNormalizer
      APPLE_STANDARD_LABEL = /\A_\$!<(?<label>.+)>!\$_\z/

      def self.normalize(label)
        match = label&.match(APPLE_STANDARD_LABEL)
        match ? match[:label] : label
      end
    end
  end
end
