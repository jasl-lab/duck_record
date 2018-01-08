# This class is inherited by the has_one and belongs_to association classes
module DuckRecord::Associations::Builder # :nodoc:
  class SingularAssociation < Association #:nodoc:
    def self.define_validations(model, reflection)
      super

      if reflection.options[:required]
        model.validates_presence_of reflection.name, message: :required
      end
    end

    def self.define_accessors(model, reflection)
      super
      mixin = model.generated_association_methods
      name = reflection.name

      define_constructors(mixin, name) if reflection.constructable?
    end

    # Defines the (build|create)_association methods for belongs_to or has_one association
    def self.define_constructors(mixin, name)
      mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def build_#{name}(*args, &block)
          association(:#{name}).build(*args, &block)
        end
      CODE
    end
  end
end
