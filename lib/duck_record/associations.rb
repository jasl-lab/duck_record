require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/conversions"
require "active_support/core_ext/module/remove_method"
require "duck_record/errors"

module DuckRecord
  class AssociationNotFoundError < ConfigurationError #:nodoc:
    def initialize(record = nil, association_name = nil)
      if record && association_name
        super("Association named '#{association_name}' was not found on #{record.class.name}; perhaps you misspelled it?")
      else
        super("Association was not found.")
      end
    end
  end

  # See ActiveRecord::Associations::ClassMethods for documentation.
  module Associations # :nodoc:
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern

    # These classes will be loaded when associations are created.
    # So there is no need to eager load them.
    autoload :EmbedsAssociation
    autoload :EmbedsManyProxy

    autoload :Association
    autoload :SingularAssociation

    module Builder #:nodoc:
      autoload :Association,           "duck_record/associations/builder/association"
      autoload :SingularAssociation,   "duck_record/associations/builder/singular_association"
      autoload :CollectionAssociation, "duck_record/associations/builder/collection_association"

      autoload :EmbedsOne,  "duck_record/associations/builder/embeds_one"
      autoload :EmbedsMany, "duck_record/associations/builder/embeds_many"

      autoload :BelongsTo, "duck_record/associations/builder/belongs_to"
    end

    eager_autoload do
      autoload :EmbedsManyAssociation
      autoload :EmbedsOneAssociation

      autoload :BelongsToAssociation
    end

    # Returns the association instance for the given name, instantiating it if it doesn't already exist
    def association(name) #:nodoc:
      association = association_instance_get(name)

      if association.nil?
        unless reflection = self.class._reflect_on_association(name)
          raise AssociationNotFoundError.new(self, name)
        end
        association = reflection.association_class.new(self, reflection)
        association_instance_set(name, association)
      end

      association
    end

    def association_cached?(name) # :nodoc
      @association_cache.key?(name)
    end

    def initialize_dup(*) # :nodoc:
      @association_cache = {}
      super
    end

    private
      # Clears out the association cache.
      def clear_association_cache
        @association_cache.clear if persisted?
      end

      def init_internals
        @association_cache = {}
        super
      end

      # Returns the specified association instance if it exists, +nil+ otherwise.
      def association_instance_get(name)
        @association_cache[name]
      end

      # Set the specified association instance.
      def association_instance_set(name, association)
        @association_cache[name] = association
      end

      module ClassMethods
        def embeds_many(name, options = {}, &extension)
          reflection = Builder::EmbedsMany.build(self, name, nil, options, &extension)
          Reflection.add_reflection self, name, reflection
        end

        def embeds_one(name, options = {})
          reflection = Builder::EmbedsOne.build(self, name, nil, options)
          Reflection.add_reflection self, name, reflection
        end

        def belongs_to(name, scope = nil, options = {})
          reflection = Builder::BelongsTo.build(self, name, scope, options)
          Reflection.add_reflection self, name, reflection
        end
      end
  end
end
