module DuckRecord #:nodoc:
  # = Active Record \Serialization
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    included do
      self.include_root_in_json = false
    end
  end
end
