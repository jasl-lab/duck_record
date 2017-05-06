require "active_support/core_ext/array/wrap"

module DuckRecord
  module Associations
    # = Active Record Associations
    #
    # This is the root class of all associations ('+ Foo' signifies an included module Foo):
    #
    #   Association
    #     SingularAssociation
    #       HasOneAssociation + ForeignAssociation
    #         HasOneThroughAssociation + ThroughAssociation
    #       BelongsToAssociation
    #         BelongsToPolymorphicAssociation
    #     CollectionAssociation
    #       HasManyAssociation + ForeignAssociation
    #         HasManyThroughAssociation + ThroughAssociation
    class Association #:nodoc:
      attr_reader :owner, :target, :reflection

      delegate :options, to: :reflection

      def initialize(owner, reflection)
        reflection.check_validity!

        @owner, @reflection = owner, reflection

        reset
      end

      # Resets the \loaded flag to +false+ and sets the \target to +nil+.
      def reset
        @target = nil
      end

      # Has the \target been already \loaded?
      def loaded?
        !!@target
      end

      # Sets the target of this association to <tt>\target</tt>, and the \loaded flag to +true+.
      def target=(target)
        @target = target
      end

      # Returns the class of the target. belongs_to polymorphic overrides this to look at the
      # polymorphic_type field on the owner.
      def klass
        reflection.klass
      end

      # We can't dump @reflection since it contains the scope proc
      def marshal_dump
        ivars = (instance_variables - [:@reflection]).map { |name| [name, instance_variable_get(name)] }
        [@reflection.name, ivars]
      end

      def marshal_load(data)
        reflection_name, ivars = data
        ivars.each { |name, val| instance_variable_set(name, val) }
        @reflection = @owner.class._reflect_on_association(reflection_name)
      end

      def initialize_attributes(record, attributes = nil) #:nodoc:
        attributes ||= {}
        record.assign_attributes(attributes)
      end

      private

        # Raises ActiveRecord::AssociationTypeMismatch unless +record+ is of
        # the kind of the class of the associated objects. Meant to be used as
        # a sanity check when you are about to assign an associated record.
        def raise_on_type_mismatch!(record)
          unless record.is_a?(reflection.klass)
            fresh_class = reflection.class_name.safe_constantize
            unless fresh_class && record.is_a?(fresh_class)
              message = "#{reflection.class_name}(##{reflection.klass.object_id}) expected, "\
                "got #{record.inspect} which is an instance of #{record.class}(##{record.class.object_id})"
              raise ActiveRecord::AssociationTypeMismatch, message
            end
          end
        end

        def build_record(attributes)
          reflection.build_association(attributes) do |record|
            initialize_attributes(record, attributes)
          end
        end
    end
  end
end
