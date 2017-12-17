module DuckRecord #:nodoc:
  # = Active Record \Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    included do
      self.include_root_in_json = false
    end

    def serializable_hash(options = {})
      options = (options || {}).reverse_merge except: Array(options[:except]).map(&:to_s)
      super options
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
