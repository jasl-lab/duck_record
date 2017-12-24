module DuckRecord
  module Associations
    class EmbedsOneAssociation < EmbedsAssociation #:nodoc:
      # Implements the reader method, e.g. foo.bar for Foo.has_one :bar
      def reader
        target
      end

      # Implements the writer method, e.g. foo.bar= for Foo.belongs_to :bar
      def writer(record)
        replace(record)
      end

      def build(attributes = {})
        record = build_record(attributes)
        yield(record) if block_given?
        set_new_record(record)
        record
      end

      # Implements the reload reader method, e.g. foo.reload_bar for
      # Foo.has_one :bar
      def force_reload_reader
        klass.uncached { reload }
        target
      end

      private

        def replace(record)
          self.target =
            if record.is_a? klass
              record
            elsif record.respond_to?(:to_h)
              build_record(record.to_h)
            end
        rescue
          raise_on_type_mismatch!(record)
        end

        def set_new_record(record)
          replace(record)
        end
    end
  end
end
