module DuckRecord
  module ReadonlyAttributes
    extend ActiveSupport::Concern

    included do
      attr_accessor :_attr_readonly_enabled
      class_attribute :_attr_readonly, instance_accessor: false
      self._attr_readonly = []
    end

    def attr_readonly_enabled?
      _attr_readonly_enabled
    end

    def enable_attr_readonly!
      self._attr_readonly_enabled = true
    end

    def disable_attr_readonly!
      self._attr_readonly_enabled = false
    end

    module ClassMethods
      # Attributes listed as readonly will be used to create a new record but update operations will
      # ignore these fields.
      def attr_readonly(*attributes)
        self._attr_readonly = Set.new(attributes.map(&:to_s)) + (_attr_readonly || [])
      end

      # Returns an array of all the attributes that have been specified as readonly.
      def readonly_attributes
        _attr_readonly
      end
    end
  end
end
