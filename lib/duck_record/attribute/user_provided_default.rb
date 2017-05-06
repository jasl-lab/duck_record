require "duck_record/attribute"

module DuckRecord
  class Attribute # :nodoc:
    class UserProvidedDefault < FromUser # :nodoc:
      def initialize(name, value, type, default)
        @user_provided_value = value
        super(name, value, type, default)
      end

      def value_before_type_cast
        if user_provided_value.is_a?(Proc)
          @memoized_value_before_type_cast ||= user_provided_value.call
        else
          @user_provided_value
        end
      end

      def with_type(type)
        self.class.new(name, user_provided_value, type, original_attribute)
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected

        attr_reader :user_provided_value
    end
  end
end
