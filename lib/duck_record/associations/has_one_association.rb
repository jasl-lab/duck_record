module DuckRecord
  # = Active Record Has One Association
  module Associations
    class HasOneAssociation < SingularAssociation #:nodoc:
      include ForeignAssociation

      def replace(record)
        if owner.class.readonly_attributes.include?(reflection.foreign_key.to_s)
          return
        end

        raise_on_type_mismatch!(record) if record
        load_target

        return target unless target || record

        self.target = record
      end

      private

        def foreign_key_present?
          true
        end

        # The reason that the save param for replace is false, if for create (not just build),
        # is because the setting of the foreign keys is actually handled by the scoping when
        # the record is instantiated, and so they are set straight away and do not need to be
        # updated within replace.
        def set_new_record(record)
          replace(record)
        end

        def nullify_owner_attributes(record)
          record[reflection.foreign_key] = nil
        end
    end
  end
end
