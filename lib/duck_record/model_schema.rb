module DuckRecord
  module ModelSchema
    extend ActiveSupport::Concern

    included do
      delegate :type_for_attribute, to: :class
    end

    module ClassMethods
      def attribute_types # :nodoc:
        load_schema
        @attribute_types ||= Hash.new(Type.default_value)
      end

      def yaml_encoder # :nodoc:
        @yaml_encoder ||= AttributeSet::YAMLEncoder.new(attribute_types)
      end

      # Returns the type of the attribute with the given name, after applying
      # all modifiers. This method is the only valid source of information for
      # anything related to the types of a model's attributes. This method will
      # access the database and load the model's schema if it is required.
      #
      # The return value of this method will implement the interface described
      # by ActiveModel::Type::Value (though the object itself may not subclass
      # it).
      #
      # +attr_name+ The name of the attribute to retrieve the type for. Must be
      # a string
      def type_for_attribute(attr_name, &block)
        if block
          attribute_types.fetch(attr_name, &block)
        else
          attribute_types[attr_name]
        end
      end

      def _default_attributes # :nodoc:
        @default_attributes ||= AttributeSet.new({})
      end

      private

        def schema_loaded?
          defined?(@schema_loaded) && @schema_loaded
        end

        def load_schema
          unless schema_loaded?
            load_schema!
          end
        end

        def load_schema!
          @schema_loaded = true
        end

        def reload_schema_from_cache
          @attribute_types = nil
          @default_attributes = nil
          @attributes_builder = nil
          @schema_loaded = false
          @attribute_names = nil
          @yaml_encoder = nil
          direct_descendants.each do |descendant|
            descendant.send(:reload_schema_from_cache)
          end
        end
    end
  end
end
