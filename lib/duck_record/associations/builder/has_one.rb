module DuckRecord::Associations::Builder # :nodoc:
  class HasOne < SingularAssociation #:nodoc:
    def self.macro
      :has_one
    end

    def self.define_validations(model, reflection)
      super

      if reflection.options[:required]
        model.validates_presence_of reflection.name, message: :required
      end
    end
  end
end
