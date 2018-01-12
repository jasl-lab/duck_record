module DuckRecord
  # = Active Record Has Many Association
  module Associations
    # This is the proxy that handles a has many association.
    #
    # If the association has a <tt>:through</tt> option further specialization
    # is provided by its child HasManyThroughAssociation.
    class HasManyAssociation < CollectionAssociation #:nodoc:
      include ForeignAssociation

      def insert_record(record, validate = true, raise = false)
        set_owner_attributes(record)
        super
      end
    end
  end
end
