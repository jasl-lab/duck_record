require "thread"
require "active_support/core_ext/string/filters"
require "active_support/deprecation"

module DuckRecord
  # = Active Record Reflection
  module Reflection # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :_reflections, instance_writer: false
      self._reflections = {}
    end

    def self.create(macro, name, scope, options, ar)
      klass = \
        case macro
        when :embeds_many
          EmbedsManyReflection
        when :embeds_one
          EmbedsOneReflection
        when :belongs_to
          BelongsToReflection
        when :has_many
          HasManyReflection
        when :has_one
          HasOneReflection
        else
          raise "Unsupported Macro: #{macro}"
        end

      reflection = klass.new(name, scope, options, ar)
      options[:through] ? ThroughReflection.new(reflection) : reflection
    end

    def self.add_reflection(ar, name, reflection)
      ar.clear_reflections_cache
      ar._reflections = ar._reflections.merge(name.to_s => reflection)
    end

    # \Reflection enables the ability to examine the associations and aggregations of
    # Active Record classes and objects. This information, for example,
    # can be used in a form builder that takes an Active Record object
    # and creates input fields for all of the attributes depending on their type
    # and displays the associations to other objects.
    #
    # MacroReflection class has info for AggregateReflection and AssociationReflection
    # classes.
    module ClassMethods
      # Returns a Hash of name of the reflection as the key and an AssociationReflection as the value.
      #
      #   Account.reflections # => {"balance" => AggregateReflection}
      #
      def reflections
        @__reflections ||= begin
          ref = {}

          _reflections.each do |name, reflection|
            parent_reflection = reflection.parent_reflection

            if parent_reflection
              parent_name = parent_reflection.name
              ref[parent_name.to_s] = parent_reflection
            else
              ref[name] = reflection
            end
          end

          ref
        end
      end

      # Returns an array of AssociationReflection objects for all the
      # associations in the class. If you only want to reflect on a certain
      # association type, pass in the symbol (<tt>:has_many</tt>, <tt>:has_one</tt>,
      # <tt>:belongs_to</tt>) as the first parameter.
      #
      # Example:
      #
      #   Account.reflect_on_all_associations             # returns an array of all associations
      #   Account.reflect_on_all_associations(:has_many)  # returns an array of all has_many associations
      #
      def reflect_on_all_associations(macro = nil)
        association_reflections = reflections.values
        association_reflections.select! { |reflection| reflection.macro == macro } if macro
        association_reflections
      end

      # Returns the AssociationReflection object for the +association+ (use the symbol).
      #
      #   Account.reflect_on_association(:owner)             # returns the owner AssociationReflection
      #   Invoice.reflect_on_association(:line_items).macro  # returns :has_many
      #
      def reflect_on_association(association)
        reflections[association.to_s]
      end

      def _reflect_on_association(association) #:nodoc:
        _reflections[association.to_s]
      end

      def clear_reflections_cache # :nodoc:
        @__reflections = nil
      end
    end

    # Holds all the methods that are shared between MacroReflection and ThroughReflection.
    #
    #   AbstractReflection
    #     MacroReflection
    #       AggregateReflection
    #       AssociationReflection
    #         HasManyReflection
    #         HasOneReflection
    #         BelongsToReflection
    #         HasAndBelongsToManyReflection
    #     ThroughReflection
    #     PolymorphicReflection
    #       RuntimeReflection
    class AbstractReflection
      # Returns a new, unsaved instance of the associated class. +attributes+ will
      # be passed to the class's constructor.
      def build_association(attributes, &block)
        klass.new(attributes, &block)
      end

      # Returns the class name for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>'Money'</tt>
      # <tt>has_many :clients</tt> returns <tt>'Client'</tt>
      def class_name
        @class_name ||= (options[:class_name] || derive_class_name).to_s
      end

      def check_validity!
        true
      end

      def alias_candidate(name)
        "#{plural_name}_#{name}"
      end
    end

    # Base class for AggregateReflection and AssociationReflection. Objects of
    # AggregateReflection and AssociationReflection are returned by the Reflection::ClassMethods.
    class MacroReflection < AbstractReflection
      # Returns the name of the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>:balance</tt>
      # <tt>has_many :clients</tt> returns <tt>:clients</tt>
      attr_reader :name

      attr_reader :scope

      # Returns the hash of options used for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns <tt>{ class_name: "Money" }</tt>
      # <tt>has_many :clients</tt> returns <tt>{}</tt>
      attr_reader :options

      attr_reader :duck_record

      attr_reader :plural_name # :nodoc:

      def initialize(name, scope, options, duck_record)
        @name          = name
        @scope         = scope
        @options       = options
        @duck_record   = duck_record
        @klass         = options[:anonymous_class]
        @plural_name   = name.to_s.pluralize
      end

      # Returns the class for the macro.
      #
      # <tt>composed_of :balance, class_name: 'Money'</tt> returns the Money class
      # <tt>has_many :clients</tt> returns the Client class
      def klass
        @klass ||= compute_class(class_name)
      end

      def compute_class(name)
        name.constantize
      end

      # Returns +true+ if +self+ and +other_aggregation+ have the same +name+ attribute, +active_record+ attribute,
      # and +other_aggregation+ has an options hash assigned to it.
      def ==(other_aggregation)
        super ||
          other_aggregation.kind_of?(self.class) &&
            name == other_aggregation.name &&
            !other_aggregation.options.nil? &&
            active_record == other_aggregation.active_record
      end

      private

        def derive_class_name
          name.to_s.camelize
        end
    end

    # Holds all the metadata about an association as it was specified in the
    # Active Record class.
    class EmbedsAssociationReflection < MacroReflection
      # Returns the target association's class.
      #
      #   class Author < ActiveRecord::Base
      #     has_many :books
      #   end
      #
      #   Author.reflect_on_association(:books).klass
      #   # => Book
      #
      # <b>Note:</b> Do not call +klass.new+ or +klass.create+ to instantiate
      # a new association object. Use +build_association+ or +create_association+
      # instead. This allows plugins to hook into association object creation.
      def klass
        @klass ||= compute_class(class_name)
      end

      def compute_class(name)
        duck_record.send(:compute_type, name)
      end

      attr_accessor :parent_reflection # Reflection

      def initialize(name, scope, options, duck_record)
        super
        @constructable = calculate_constructable(macro, options)

        if options[:class_name] && options[:class_name].class == Class
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Passing a class to the `class_name` is deprecated and will raise
            an ArgumentError in Rails 5.2. It eagerloads more classes than
            necessary and potentially creates circular dependencies.

            Please pass the class name as a string:
            `#{macro} :#{name}, class_name: '#{options[:class_name]}'`
          MSG
        end
      end

      def constructable? # :nodoc:
        @constructable
      end

      def source_reflection
        self
      end

      def nested?
        false
      end

      # Returns the macro type.
      #
      # <tt>has_many :clients</tt> returns <tt>:has_many</tt>
      def macro; raise NotImplementedError; end

      # Returns whether or not this association reflection is for a collection
      # association. Returns +true+ if the +macro+ is either +has_many+ or
      # +has_and_belongs_to_many+, +false+ otherwise.
      def collection?
        false
      end

      # Returns whether or not the association should be validated as part of
      # the parent's validation.
      #
      # Unless you explicitly disable validation with
      # <tt>validate: false</tt>, validation will take place when:
      #
      # * you explicitly enable validation; <tt>validate: true</tt>
      # * you use autosave; <tt>autosave: true</tt>
      # * the association is a +has_many+ association
      def validate?
        !options[:validate].nil? ? options[:validate] : collection?
      end

      # Returns +true+ if +self+ is a +has_one+ reflection.
      def has_one?; false; end

      def association_class; raise NotImplementedError; end

      def add_as_source(seed)
        seed
      end

      protected

        def actual_source_reflection # FIXME: this is a horrible name
          self
        end

      private

        def calculate_constructable(macro, options)
          true
        end

        def derive_class_name
          class_name = name.to_s
          class_name = class_name.singularize if collection?
          class_name.camelize
        end
    end

    class EmbedsManyReflection < EmbedsAssociationReflection
      def macro; :embeds_many; end

      def collection?; true; end

      def association_class
        Associations::EmbedsManyAssociation
      end
    end

    class EmbedsOneReflection < EmbedsAssociationReflection
      def macro; :embeds_one; end

      def has_one?; true; end

      def association_class
        Associations::EmbedsOneAssociation
      end
    end

    # Holds all the metadata about an association as it was specified in the
    # Active Record class.
    class AssociationReflection < MacroReflection
      alias active_record duck_record

      def through_reflection?
        false
      end

      def quoted_table_name
        klass.quoted_table_name
      end

      def primary_key_type
        klass.type_for_attribute(klass.primary_key)
      end

      JoinKeys = Struct.new(:key, :foreign_key) # :nodoc:

      def join_keys
        get_join_keys klass
      end

      # Returns a list of scopes that should be applied for this Reflection
      # object when querying the database.
      def scopes
        scope ? [scope] : []
      end

      def scope_chain
        chain.map(&:scopes)
      end
      deprecate :scope_chain

      def join_scopes(table, predicate_builder) # :nodoc:
        if scope
          [ActiveRecord::Relation.create(klass, table, predicate_builder)
             .instance_exec(&scope)]
        else
          []
        end
      end

      def klass_join_scope(table, predicate_builder) # :nodoc:
        relation = ActiveRecord::Relation.create(klass, table, predicate_builder)
        klass.scope_for_association(relation)
      end

      def constraints
        chain.map(&:scopes).flatten
      end

      def alias_candidate(name)
        "#{plural_name}_#{name}"
      end

      def chain
        collect_join_chain
      end

      def get_join_keys(association_klass)
        JoinKeys.new(join_pk(association_klass), join_fk)
      end

      # Returns the target association's class.
      #
      #   class Author < ActiveRecord::Base
      #     has_many :books
      #   end
      #
      #   Author.reflect_on_association(:books).klass
      #   # => Book
      #
      # <b>Note:</b> Do not call +klass.new+ or +klass.create+ to instantiate
      # a new association object. Use +build_association+ or +create_association+
      # instead. This allows plugins to hook into association object creation.
      def klass
        @klass ||= compute_class(class_name)
      end

      def compute_class(name)
        active_record.send(:compute_type, name)
      end

      def table_name
        klass.table_name
      end

      attr_reader :type, :foreign_type
      attr_accessor :parent_reflection # Reflection

      def initialize(name, scope, options, active_record)
        super
        @type         = options[:as] && (options[:foreign_type] || "#{options[:as]}_type")
        @foreign_type = options[:foreign_type] || "#{name}_type"
        @constructable = calculate_constructable(macro, options)
        @association_scope_cache = {}
        @scope_lock = Mutex.new

        if options[:class_name] && options[:class_name].class == Class
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Passing a class to the `class_name` is deprecated and will raise
            an ArgumentError in Rails 5.2. It eagerloads more classes than
            necessary and potentially creates circular dependencies.

            Please pass the class name as a string:
            `#{macro} :#{name}, class_name: '#{options[:class_name]}'`
          MSG
        end
      end

      def association_scope_cache(conn, owner)
        key = conn.prepared_statements
        @association_scope_cache[key] ||= @scope_lock.synchronize {
          @association_scope_cache[key] ||= yield
        }
      end

      def constructable? # :nodoc:
        @constructable
      end

      def join_table
        @join_table ||= options[:join_table] || derive_join_table
      end

      def foreign_key
        @foreign_key ||= options[:foreign_key] || derive_foreign_key.freeze
      end

      def association_foreign_key
        @association_foreign_key ||= options[:association_foreign_key] || class_name.foreign_key
      end

      # klass option is necessary to support loading polymorphic associations
      def association_primary_key(klass = nil)
        options[:primary_key] || primary_key(klass || self.klass)
      end

      def association_primary_key_type
        klass.type_for_attribute(association_primary_key.to_s)
      end

      def active_record_primary_key
        @active_record_primary_key ||= options[:primary_key] || primary_key(active_record)
      end

      def check_validity!
        unless klass < ActiveRecord::Base
          raise ArgumentError, "#{klass} must be inherited from ActiveRecord::Base."
        end
      end

      def check_preloadable!
        return unless scope

        if scope.arity > 0
          raise ArgumentError, <<-MSG.squish
            The association scope '#{name}' is instance dependent (the scope
            block takes an argument). Preloading instance dependent scopes is
            not supported.
          MSG
        end
      end
      alias :check_eager_loadable! :check_preloadable!

      def join_id_for(owner) # :nodoc:
        owner[active_record_primary_key]
      end

      def through_reflection
        nil
      end

      def source_reflection
        self
      end

      # A chain of reflections from this one back to the owner. For more see the explanation in
      # ThroughReflection.
      def collect_join_chain
        [self]
      end

      # This is for clearing cache on the reflection. Useful for tests that need to compare
      # SQL queries on associations.
      def clear_association_scope_cache # :nodoc:
        @association_scope_cache.clear
      end

      def nested?
        false
      end

      def has_scope?
        scope
      end

      # Returns the macro type.
      #
      # <tt>has_many :clients</tt> returns <tt>:has_many</tt>
      def macro; raise NotImplementedError; end

      # Returns whether or not this association reflection is for a collection
      # association. Returns +true+ if the +macro+ is either +has_many+ or
      # +has_and_belongs_to_many+, +false+ otherwise.
      def collection?
        false
      end

      # Returns whether or not the association should be validated as part of
      # the parent's validation.
      #
      # Unless you explicitly disable validation with
      # <tt>validate: false</tt>, validation will take place when:
      #
      # * you explicitly enable validation; <tt>validate: true</tt>
      # * you use autosave; <tt>autosave: true</tt>
      # * the association is a +has_many+ association
      def validate?
        !options[:validate].nil? ? options[:validate] : (options[:autosave] == true || collection?)
      end

      # Returns +true+ if +self+ is a +belongs_to+ reflection.
      def belongs_to?; false; end

      # Returns +true+ if +self+ is a +has_one+ reflection.
      def has_one?; false; end

      def association_class; raise NotImplementedError; end

      def add_as_source(seed)
        seed
      end

      def add_as_through(seed)
        seed + [self]
      end

      def extensions
        Array(options[:extend])
      end

      protected

      def actual_source_reflection # FIXME: this is a horrible name
        self
      end

      private

      def join_pk(_)
        foreign_key
      end

      def join_fk
        active_record_primary_key
      end

      def calculate_constructable(_macro, _options)
        false
      end

      def derive_class_name
        class_name = name.to_s
        class_name = class_name.singularize if collection?
        class_name.camelize
      end

      def derive_foreign_key
        if options[:as]
          "#{options[:as]}_id"
        else
          "#{name}_id"
        end
      end

      def primary_key(klass)
        klass.primary_key || raise(ActiveRecord::UnknownPrimaryKey.new(klass))
      end
    end

    class BelongsToReflection < AssociationReflection # :nodoc:
      def macro; :belongs_to; end

      def belongs_to?; true; end

      def association_class
        Associations::BelongsToAssociation
      end

      def join_id_for(owner) # :nodoc:
        owner[foreign_key]
      end

      private

      def join_fk
        foreign_key
      end

      def join_pk(_klass)
        association_primary_key
      end
    end

    class HasManyReflection < AssociationReflection # :nodoc:
      def macro; :has_many; end

      def collection?; true; end

      def association_class
        if options[:through]
          Associations::HasManyThroughAssociation
        else
          Associations::HasManyAssociation
        end
      end

      def association_primary_key(klass = nil)
        primary_key(klass || self.klass)
      end
    end

    class HasOneReflection < AssociationReflection # :nodoc:
      def macro; :has_one; end

      def has_one?; true; end

      def association_class
        if options[:through]
          Associations::HasOneThroughAssociation
        else
          Associations::HasOneAssociation
        end
      end
    end

    # Holds all the metadata about a :through association as it was specified
    # in the Active Record class.
    class ThroughReflection < AbstractReflection #:nodoc:
      attr_reader :delegate_reflection
      delegate :foreign_key, :foreign_type, :association_foreign_key,
               :active_record_primary_key, :type, :get_join_keys, to: :source_reflection

      def initialize(delegate_reflection)
        @delegate_reflection = delegate_reflection
        @klass = delegate_reflection.options[:anonymous_class]
        @source_reflection_name = delegate_reflection.options[:source]
      end

      def through_reflection?
        true
      end

      def klass
        @klass ||= delegate_reflection.compute_class(class_name)
      end

      # Returns the source of the through reflection. It checks both a singularized
      # and pluralized form for <tt>:belongs_to</tt> or <tt>:has_many</tt>.
      #
      #   class Post < ActiveRecord::Base
      #     has_many :taggings
      #     has_many :tags, through: :taggings
      #   end
      #
      #   class Tagging < ActiveRecord::Base
      #     belongs_to :post
      #     belongs_to :tag
      #   end
      #
      #   tags_reflection = Post.reflect_on_association(:tags)
      #   tags_reflection.source_reflection
      #   # => <ActiveRecord::Reflection::BelongsToReflection: @name=:tag, @active_record=Tagging, @plural_name="tags">
      #
      def source_reflection
        through_reflection.klass._reflect_on_association(source_reflection_name)
      end

      # Returns the AssociationReflection object specified in the <tt>:through</tt> option
      # of a HasManyThrough or HasOneThrough association.
      #
      #   class Post < ActiveRecord::Base
      #     has_many :taggings
      #     has_many :tags, through: :taggings
      #   end
      #
      #   tags_reflection = Post.reflect_on_association(:tags)
      #   tags_reflection.through_reflection
      #   # => <ActiveRecord::Reflection::HasManyReflection: @name=:taggings, @active_record=Post, @plural_name="taggings">
      #
      def through_reflection
        active_record._reflect_on_association(options[:through])
      end

      # Returns an array of reflections which are involved in this association. Each item in the
      # array corresponds to a table which will be part of the query for this association.
      #
      # The chain is built by recursively calling #chain on the source reflection and the through
      # reflection. The base case for the recursion is a normal association, which just returns
      # [self] as its #chain.
      #
      #   class Post < ActiveRecord::Base
      #     has_many :taggings
      #     has_many :tags, through: :taggings
      #   end
      #
      #   tags_reflection = Post.reflect_on_association(:tags)
      #   tags_reflection.chain
      #   # => [<ActiveRecord::Reflection::ThroughReflection: @delegate_reflection=#<ActiveRecord::Reflection::HasManyReflection: @name=:tags...>,
      #         <ActiveRecord::Reflection::HasManyReflection: @name=:taggings, @options={}, @active_record=Post>]
      #
      def collect_join_chain
        collect_join_reflections [self]
      end

      # This is for clearing cache on the reflection. Useful for tests that need to compare
      # SQL queries on associations.
      def clear_association_scope_cache # :nodoc:
        delegate_reflection.clear_association_scope_cache
        source_reflection.clear_association_scope_cache
        through_reflection.clear_association_scope_cache
      end

      def scopes
        source_reflection.scopes + super
      end

      def join_scopes(table, predicate_builder) # :nodoc:
        source_reflection.join_scopes(table, predicate_builder) + super
      end

      def source_type_scope
        through_reflection.klass.where(foreign_type => options[:source_type])
      end

      def has_scope?
        scope || options[:source_type] ||
          source_reflection.has_scope? ||
          through_reflection.has_scope?
      end

      # A through association is nested if there would be more than one join table
      def nested?
        source_reflection.through_reflection? || through_reflection.through_reflection?
      end

      # We want to use the klass from this reflection, rather than just delegate straight to
      # the source_reflection, because the source_reflection may be polymorphic. We still
      # need to respect the source_reflection's :primary_key option, though.
      def association_primary_key(klass = nil)
        # Get the "actual" source reflection if the immediate source reflection has a
        # source reflection itself
        actual_source_reflection.options[:primary_key] || primary_key(klass || self.klass)
      end

      def association_primary_key_type
        klass.type_for_attribute(association_primary_key.to_s)
      end

      # Gets an array of possible <tt>:through</tt> source reflection names in both singular and plural form.
      #
      #   class Post < ActiveRecord::Base
      #     has_many :taggings
      #     has_many :tags, through: :taggings
      #   end
      #
      #   tags_reflection = Post.reflect_on_association(:tags)
      #   tags_reflection.source_reflection_names
      #   # => [:tag, :tags]
      #
      def source_reflection_names
        options[:source] ? [options[:source]] : [name.to_s.singularize, name].uniq
      end

      def source_reflection_name # :nodoc:
        return @source_reflection_name if @source_reflection_name

        names = [name.to_s.singularize, name].collect(&:to_sym).uniq
        names = names.find_all { |n|
          through_reflection.klass._reflect_on_association(n)
        }

        if names.length > 1
          raise AmbiguousSourceReflectionForThroughAssociation.new(
            active_record.name,
            macro,
            name,
            options,
            source_reflection_names
          )
        end

        @source_reflection_name = names.first
      end

      def source_options
        source_reflection.options
      end

      def through_options
        through_reflection.options
      end

      def join_id_for(owner) # :nodoc:
        source_reflection.join_id_for(owner)
      end

      def check_validity!
        if through_reflection.nil?
          raise HasManyThroughAssociationNotFoundError.new(active_record.name, self)
        end

        if source_reflection.nil?
          raise HasManyThroughSourceAssociationNotFoundError.new(self)
        end

        if has_one? && through_reflection.collection?
          raise HasOneThroughCantAssociateThroughCollection.new(active_record.name, self, through_reflection)
        end

        if parent_reflection.nil?
          reflections = active_record.reflections.keys.map(&:to_sym)

          if reflections.index(through_reflection.name) > reflections.index(name)
            raise HasManyThroughOrderError.new(active_record.name, self, through_reflection)
          end
        end
      end

      def constraints
        scope_chain = source_reflection.constraints
        scope_chain << scope if scope
        scope_chain
      end

      def add_as_source(seed)
        collect_join_reflections seed
      end

      def add_as_polymorphic_through(reflection, seed)
        collect_join_reflections(seed + [PolymorphicReflection.new(self, reflection)])
      end

      def add_as_through(seed)
        collect_join_reflections(seed + [self])
      end

      def collect_join_reflections(seed)
        a = source_reflection.add_as_source seed
        if options[:source_type]
          through_reflection.add_as_polymorphic_through self, a
        else
          through_reflection.add_as_through a
        end
      end

      private

      def actual_source_reflection # FIXME: this is a horrible name
        source_reflection.send(:actual_source_reflection)
      end

      def primary_key(klass)
        klass.primary_key || raise(UnknownPrimaryKey.new(klass))
      end

      def derive_class_name
        # get the class_name of the belongs_to association of the through reflection
        options[:source_type] || source_reflection.class_name
      end

      delegate_methods = AssociationReflection.public_instance_methods -
        public_instance_methods

      delegate(*delegate_methods, to: :delegate_reflection)
    end
  end
end
