module DuckRecord #:nodoc:
  # = Active Record \Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    included do
      self.include_root_in_json = false
    end

    private

    def read_attribute_for_serialization(key)
      v = send(key)
      if v.respond_to?(:serializable_hash)
        v.serializable_hash
      elsif v.respond_to?(:to_ary)
        v.to_ary
      elsif v.respond_to?(:to_hash)
        v.to_hash
      else
        v
      end
    end
  end
end
