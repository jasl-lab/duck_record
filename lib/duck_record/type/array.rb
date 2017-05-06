module DuckRecord
  module Type # :nodoc:
    class Array < ActiveModel::Type::Value # :nodoc:
      include ActiveModel::Type::Helpers::Mutable

      attr_reader :subtype
      delegate :type, :user_input_in_time_zone, :limit, to: :subtype

      def initialize(subtype)
        @subtype = subtype
      end

      def cast(value)
        type_cast_array(value, :cast)
      end

      def ==(other)
        other.is_a?(Array) && subtype == other.subtype
      end

      def map(value, &block)
        value.map(&block)
      end

      private

        def type_cast_array(value, method)
          if value.is_a?(::Array)
            value.map { |item| type_cast_array(item, method) }
          else
            @subtype.public_send(method, value)
          end
        end
    end
  end
end
