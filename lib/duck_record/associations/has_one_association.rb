module DuckRecord
  # = Active Record Has One Association
  module Associations
    class HasOneAssociation < SingularAssociation #:nodoc:
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
    end
  end
end
