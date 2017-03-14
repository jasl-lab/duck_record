module DuckRecord
  module Associations
    class SingularAssociation < Association #:nodoc:
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

      def replace(_record)
        raise NotImplementedError, "Subclasses must implement a replace(record) method"
      end

      def set_new_record(record)
        replace(record)
      end
    end
  end
end
