module DuckRecord
  module AttributeMethods
    module Write
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "="
      end

      module ClassMethods
        private

          def define_method_attribute=(name)
            safe_name = name.unpack("h*".freeze).first
            DuckRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name

            generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
            def __temp__#{safe_name}=(value, force_write_readonly: false)
              name = ::DuckRecord::AttributeMethods::AttrNames::ATTR_#{safe_name}
              write_attribute(name, value, force_write_readonly: force_write_readonly)
            end
            alias_method #{(name + '=').inspect}, :__temp__#{safe_name}=
            undef_method :__temp__#{safe_name}=
          STR
          end
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the
      # specified +value+. Empty strings for Integer and Float columns are
      # turned into +nil+.
      def write_attribute(attr_name, value, force_write_readonly: false)
        name = if self.class.attribute_alias?(attr_name)
                 self.class.attribute_alias(attr_name).to_s
               else
                 attr_name.to_s
               end

        write_attribute_with_type_cast(name, value, true, force_write_readonly: force_write_readonly)
      end

      def raw_write_attribute(attr_name, value, force_write_readonly: false) # :nodoc:
        write_attribute_with_type_cast(attr_name, value, false, force_write_readonly: force_write_readonly)
      end

      private

        # Handle *= for method_missing.
        def attribute=(attribute_name, value, force_write_readonly: false)
          write_attribute(attribute_name, value, force_write_readonly: force_write_readonly)
        end

        def write_attribute_with_type_cast(attr_name, value, should_type_cast, force_write_readonly: false)
          attr_name = attr_name.to_s

          return if !force_write_readonly && self.class.readonly_attributes.include?(attr_name)

          if should_type_cast
            @attributes.write_from_user(attr_name, value)
          else
            @attributes.write_cast_value(attr_name, value)
          end

          value
        end
    end
  end
end
