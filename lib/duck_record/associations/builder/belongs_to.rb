module DuckRecord::Associations::Builder # :nodoc:
  class BelongsTo < SingularAssociation #:nodoc:
    def self.macro
      :belongs_to
    end

    def self.valid_options(_options)
      super + [:optional, :default]
    end

    def self.define_callbacks(model, reflection)
      super
      add_default_callbacks(model, reflection) if reflection.options[:default]
    end

    def self.define_accessors(mixin, reflection)
      super
    end

    def self.add_default_callbacks(model, reflection)
      model.before_validation lambda { |o|
        o.association(reflection.name).default(&reflection.options[:default])
      }
    end

    def self.define_validations(model, reflection)
      if reflection.options.key?(:required)
        reflection.options[:optional] = !reflection.options.delete(:required)
      end

      if reflection.options[:optional].nil?
        required = true
      else
        required = !reflection.options[:optional]
      end

      super

      if required
        model.validates_presence_of reflection.name, message: :required
      end
    end
  end
end
