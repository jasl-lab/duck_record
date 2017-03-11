require 'active_model/type'

require 'duck_record/type/internal/abstract_json'
require 'duck_record/type/json'

require 'duck_record/type/array'

require 'duck_record/type/serialized'
require 'duck_record/type/registry'

module DuckRecord
  module Type
    @registry = Registry.new

    class << self
      attr_accessor :registry # :nodoc:
      delegate :add_modifier, to: :registry

      # Add a new type to the registry, allowing it to be referenced as a
      # symbol by {ActiveRecord::Base.attribute}[rdoc-ref:Attributes::ClassMethods#attribute].
      # If your type is only meant to be used with a specific database adapter, you can
      # do so by passing <tt>adapter: :postgresql</tt>. If your type has the same
      # name as a native type for the current adapter, an exception will be
      # raised unless you specify an +:override+ option. <tt>override: true</tt> will
      # cause your type to be used instead of the native type. <tt>override:
      # false</tt> will cause the native type to be used over yours if one exists.
      def register(type_name, klass = nil, **options, &block)
        registry.register(type_name, klass, **options, &block)
      end

      def lookup(*args, **kwargs) # :nodoc:
        registry.lookup(*args, **kwargs)
      end
    end

    Helpers = ActiveModel::Type::Helpers
    BigInteger = ActiveModel::Type::BigInteger
    Binary = ActiveModel::Type::Binary
    Boolean = ActiveModel::Type::Boolean
    Decimal = ActiveModel::Type::Decimal
    DecimalWithoutScale = ActiveModel::Type::DecimalWithoutScale
    Float = ActiveModel::Type::Float
    Integer = ActiveModel::Type::Integer
    String = ActiveModel::Type::String
    Text = ActiveModel::Type::Text
    UnsignedInteger = ActiveModel::Type::UnsignedInteger
    DateTime = ActiveModel::Type::DateTime
    Time = ActiveModel::Type::Time
    Date = ActiveModel::Type::Date
    Value = ActiveModel::Type::Value

    register(:big_integer, Type::BigInteger, override: false)
    register(:binary, Type::Binary, override: false)
    register(:boolean, Type::Boolean, override: false)
    register(:date, Type::Date, override: false)
    register(:datetime, Type::DateTime, override: false)
    register(:decimal, Type::Decimal, override: false)
    register(:float, Type::Float, override: false)
    register(:integer, Type::Integer, override: false)
    register(:string, Type::String, override: false)
    register(:text, Type::Text, override: false)
    register(:time, Type::Time, override: false)
    register(:json, Type::JSON, override: false)

    add_modifier({array: true}, Type::Array)
  end
end
