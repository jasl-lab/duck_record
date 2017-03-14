module DuckRecord
  # = Active Record Has One Association
  module Associations
    class HasOneAssociation < SingularAssociation #:nodoc:
      def replace(record)
        raise_on_type_mismatch!(record) if record

        self.target = record
      end
    end
  end
end
