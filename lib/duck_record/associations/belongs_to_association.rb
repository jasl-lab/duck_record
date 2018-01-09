module DuckRecord
  # = Active Record Belongs To Association
  module Associations
    class BelongsToAssociation < SingularAssociation #:nodoc:
      def handle_dependency
        target.send(options[:dependent]) if load_target
      end

      def replace(record)
        if record
          raise_on_type_mismatch!(record)
          replace_keys(record)
          @updated = true
        else
          remove_keys
        end

        self.target = record
      end

      def default(&block)
        writer(owner.instance_exec(&block)) if reader.nil?
      end

      def reset
        super
        @updated = false
      end

      def updated?
        @updated
      end

      private

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        # Checks whether record is different to the current target, without loading it
        def different_target?(record)
          record.id != owner._read_attribute(reflection.foreign_key)
        end

        def replace_keys(record)
          owner[reflection.foreign_key] = record._read_attribute(reflection.association_primary_key(record.class))
        end

        def remove_keys
          owner[reflection.foreign_key] = nil
        end

        def foreign_key_present?
          owner._read_attribute(reflection.foreign_key)
        end

        def target_id
          if options[:primary_key]
            owner.send(reflection.name).try(:id)
          else
            owner._read_attribute(reflection.foreign_key)
          end
        end

        def stale_state
          result = owner._read_attribute(reflection.foreign_key) { |n| owner.send(:missing_attribute, n, caller) }
          result&.to_s
        end
    end
  end
end
