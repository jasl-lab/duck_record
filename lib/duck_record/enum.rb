# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"

module DuckRecord
  module Enum
    def self.extended(base) # :nodoc:
      base.class_attribute(:defined_enums, instance_writer: false)
      base.defined_enums = {}
    end

    def inherited(base) # :nodoc:
      base.defined_enums = defined_enums.deep_dup
      super
    end

    class EnumType < ActiveModel::Type::Value # :nodoc:
      delegate :type, to: :subtype

      def initialize(name, mapping, subtype)
        @name = name
        @mapping = mapping
        @subtype = subtype
      end

      def cast(value)
        return if value.blank?

        if mapping.has_key?(value)
          value.to_s
        elsif mapping.has_value?(value)
          mapping.key(value)
        else
          assert_valid_value(value)
        end
      end

      def deserialize(value)
        return if value.nil?
        mapping.key(subtype.deserialize(value))
      end

      def serialize(value)
        mapping.fetch(value, value)
      end

      def assert_valid_value(value)
        unless value.blank? || mapping.has_key?(value) || mapping.has_value?(value)
          raise ArgumentError, "'#{value}' is not a valid #{name}"
        end
      end

      private

      attr_reader :name, :mapping, :subtype
    end

    def enum(definitions)
      klass = self
      enum_prefix = definitions.delete(:_prefix)
      enum_suffix = definitions.delete(:_suffix)
      definitions.each do |name, values|
        # statuses = { }
        enum_values = ActiveSupport::HashWithIndifferentAccess.new
        name        = name.to_sym

        # def self.statuses() statuses end
        detect_enum_conflict!(name, name.to_s.pluralize, true)
        klass.singleton_class.send(:define_method, name.to_s.pluralize) { enum_values }

        detect_enum_conflict!(name, name)
        detect_enum_conflict!(name, "#{name}=")

        attr = attribute_alias?(name) ? attribute_alias(name) : name
        decorate_attribute_type(attr, :enum) do |subtype|
          EnumType.new(attr, enum_values, subtype)
        end

        _enum_methods_module.module_eval do
          pairs = values.respond_to?(:each_pair) ? values.each_pair : values.each_with_index
          pairs.each do |value, i|
            if enum_prefix == true
              prefix = "#{name}_"
            elsif enum_prefix
              prefix = "#{enum_prefix}_"
            end
            if enum_suffix == true
              suffix = "_#{name}"
            elsif enum_suffix
              suffix = "_#{enum_suffix}"
            end

            value_method_name = "#{prefix}#{value}#{suffix}"
            enum_values[value] = i

            # def active?() status == 0 end
            klass.send(:detect_enum_conflict!, name, "#{value_method_name}?")
            define_method("#{value_method_name}?") { self[attr] == value.to_s }
          end
        end
        defined_enums[name.to_s] = enum_values
      end
    end

    private
    def _enum_methods_module
      @_enum_methods_module ||= begin
        mod = Module.new
        include mod
        mod
      end
    end

    ENUM_CONFLICT_MESSAGE = \
        "You tried to define an enum named \"%{enum}\" on the model \"%{klass}\", but " \
        "this will generate a %{type} method \"%{method}\", which is already defined " \
        "by %{source}."

    def detect_enum_conflict!(enum_name, method_name, klass_method = false)
      if klass_method && dangerous_class_method?(method_name)
        raise_conflict_error(enum_name, method_name, type: "class")
      elsif !klass_method && dangerous_attribute_method?(method_name)
        raise_conflict_error(enum_name, method_name)
      elsif !klass_method && method_defined_within?(method_name, _enum_methods_module, Module)
        raise_conflict_error(enum_name, method_name, source: "another enum")
      end
    end

    def raise_conflict_error(enum_name, method_name, type: "instance", source: "Active Record")
      raise ArgumentError, ENUM_CONFLICT_MESSAGE % {
        enum: enum_name,
        klass: name,
        type: type,
        method: method_name,
        source: source
      }
    end
  end
end
