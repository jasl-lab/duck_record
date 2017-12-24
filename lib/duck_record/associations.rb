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

    autoload :EmbedsManyAssociation
    autoload :EmbedsOneAssociation

    module Builder #:nodoc:
      autoload :EmbedsAssociation, "duck_record/associations/builder/embeds_association"

      autoload :EmbedsOne,         "duck_record/associations/builder/embeds_one"
      autoload :EmbedsMany,        "duck_record/associations/builder/embeds_many"
    end

    def self.eager_load!
      super
      Preloader.eager_load!
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
        # Specifies a one-to-many association. The following methods for retrieval and query of
        # collections of associated objects will be added:
        #
        # +collection+ is a placeholder for the symbol passed as the +name+ argument, so
        # <tt>has_many :clients</tt> would add among others <tt>clients.empty?</tt>.
        #
        # [collection(force_reload = false)]
        #   Returns an array of all the associated objects.
        #   An empty array is returned if none are found.
        # [collection<<(object, ...)]
        #   Adds one or more objects to the collection by setting their foreign keys to the collection's primary key.
        #   Note that this operation instantly fires update SQL without waiting for the save or update call on the
        #   parent object, unless the parent object is a new record.
        #   This will also run validations and callbacks of associated object(s).
        # [collection.delete(object, ...)]
        #   Removes one or more objects from the collection by setting their foreign keys to +NULL+.
        #   Objects will be in addition destroyed if they're associated with <tt>dependent: :destroy</tt>,
        #   and deleted if they're associated with <tt>dependent: :delete_all</tt>.
        #
        #   If the <tt>:through</tt> option is used, then the join records are deleted (rather than
        #   nullified) by default, but you can specify <tt>dependent: :destroy</tt> or
        #   <tt>dependent: :nullify</tt> to override this.
        # [collection.destroy(object, ...)]
        #   Removes one or more objects from the collection by running <tt>destroy</tt> on
        #   each record, regardless of any dependent option, ensuring callbacks are run.
        #
        #   If the <tt>:through</tt> option is used, then the join records are destroyed
        #   instead, not the objects themselves.
        # [collection=objects]
        #   Replaces the collections content by deleting and adding objects as appropriate. If the <tt>:through</tt>
        #   option is true callbacks in the join models are triggered except destroy callbacks, since deletion is
        #   direct by default. You can specify <tt>dependent: :destroy</tt> or
        #   <tt>dependent: :nullify</tt> to override this.
        # [collection_singular_ids]
        #   Returns an array of the associated objects' ids
        # [collection_singular_ids=ids]
        #   Replace the collection with the objects identified by the primary keys in +ids+. This
        #   method loads the models and calls <tt>collection=</tt>. See above.
        # [collection.clear]
        #   Removes every object from the collection. This destroys the associated objects if they
        #   are associated with <tt>dependent: :destroy</tt>, deletes them directly from the
        #   database if <tt>dependent: :delete_all</tt>, otherwise sets their foreign keys to +NULL+.
        #   If the <tt>:through</tt> option is true no destroy callbacks are invoked on the join models.
        #   Join models are directly deleted.
        # [collection.empty?]
        #   Returns +true+ if there are no associated objects.
        # [collection.size]
        #   Returns the number of associated objects.
        # [collection.find(...)]
        #   Finds an associated object according to the same rules as ActiveRecord::FinderMethods#find.
        # [collection.exists?(...)]
        #   Checks whether an associated object with the given conditions exists.
        #   Uses the same rules as ActiveRecord::FinderMethods#exists?.
        # [collection.build(attributes = {}, ...)]
        #   Returns one or more new objects of the collection type that have been instantiated
        #   with +attributes+ and linked to this object through a foreign key, but have not yet
        #   been saved.
        # [collection.create(attributes = {})]
        #   Returns a new object of the collection type that has been instantiated
        #   with +attributes+, linked to this object through a foreign key, and that has already
        #   been saved (if it passed the validation). *Note*: This only works if the base model
        #   already exists in the DB, not if it is a new (unsaved) record!
        # [collection.create!(attributes = {})]
        #   Does the same as <tt>collection.create</tt>, but raises ActiveRecord::RecordInvalid
        #   if the record is invalid.
        #
        # === Example
        #
        # A <tt>Firm</tt> class declares <tt>has_many :clients</tt>, which will add:
        # * <tt>Firm#clients</tt> (similar to <tt>Client.where(firm_id: id)</tt>)
        # * <tt>Firm#clients<<</tt>
        # * <tt>Firm#clients.delete</tt>
        # * <tt>Firm#clients.destroy</tt>
        # * <tt>Firm#clients=</tt>
        # * <tt>Firm#client_ids</tt>
        # * <tt>Firm#client_ids=</tt>
        # * <tt>Firm#clients.clear</tt>
        # * <tt>Firm#clients.empty?</tt> (similar to <tt>firm.clients.size == 0</tt>)
        # * <tt>Firm#clients.size</tt> (similar to <tt>Client.count "firm_id = #{id}"</tt>)
        # * <tt>Firm#clients.find</tt> (similar to <tt>Client.where(firm_id: id).find(id)</tt>)
        # * <tt>Firm#clients.exists?(name: 'ACME')</tt> (similar to <tt>Client.exists?(name: 'ACME', firm_id: firm.id)</tt>)
        # * <tt>Firm#clients.build</tt> (similar to <tt>Client.new("firm_id" => id)</tt>)
        # * <tt>Firm#clients.create</tt> (similar to <tt>c = Client.new("firm_id" => id); c.save; c</tt>)
        # * <tt>Firm#clients.create!</tt> (similar to <tt>c = Client.new("firm_id" => id); c.save!</tt>)
        # The declaration can also include an +options+ hash to specialize the behavior of the association.
        #
        # === Scopes
        #
        # You can pass a second argument +scope+ as a callable (i.e. proc or
        # lambda) to retrieve a specific set of records or customize the generated
        # query when you access the associated collection.
        #
        # Scope examples:
        #   has_many :comments, -> { where(author_id: 1) }
        #   has_many :employees, -> { joins(:address) }
        #   has_many :posts, ->(post) { where("max_post_length > ?", post.length) }
        #
        # === Extensions
        #
        # The +extension+ argument allows you to pass a block into a has_many
        # association. This is useful for adding new finders, creators and other
        # factory-type methods to be used as part of the association.
        #
        # Extension examples:
        #   has_many :employees do
        #     def find_or_create_by_name(name)
        #       first_name, last_name = name.split(" ", 2)
        #       find_or_create_by(first_name: first_name, last_name: last_name)
        #     end
        #   end
        #
        # === Options
        # [:class_name]
        #   Specify the class name of the association. Use it only if that name can't be inferred
        #   from the association name. So <tt>has_many :products</tt> will by default be linked
        #   to the +Product+ class, but if the real class name is +SpecialProduct+, you'll have to
        #   specify it with this option.
        # [:foreign_key]
        #   Specify the foreign key used for the association. By default this is guessed to be the name
        #   of this class in lower-case and "_id" suffixed. So a Person class that makes a #has_many
        #   association will use "person_id" as the default <tt>:foreign_key</tt>.
        # [:foreign_type]
        #   Specify the column used to store the associated object's type, if this is a polymorphic
        #   association. By default this is guessed to be the name of the polymorphic association
        #   specified on "as" option with a "_type" suffix. So a class that defines a
        #   <tt>has_many :tags, as: :taggable</tt> association will use "taggable_type" as the
        #   default <tt>:foreign_type</tt>.
        # [:primary_key]
        #   Specify the name of the column to use as the primary key for the association. By default this is +id+.
        # [:dependent]
        #   Controls what happens to the associated objects when
        #   their owner is destroyed. Note that these are implemented as
        #   callbacks, and Rails executes callbacks in order. Therefore, other
        #   similar callbacks may affect the <tt>:dependent</tt> behavior, and the
        #   <tt>:dependent</tt> behavior may affect other callbacks.
        #
        #   * <tt>:destroy</tt> causes all the associated objects to also be destroyed.
        #   * <tt>:delete_all</tt> causes all the associated objects to be deleted directly from the database (so callbacks will not be executed).
        #   * <tt>:nullify</tt> causes the foreign keys to be set to +NULL+. Callbacks are not executed.
        #   * <tt>:restrict_with_exception</tt> causes an exception to be raised if there are any associated records.
        #   * <tt>:restrict_with_error</tt> causes an error to be added to the owner if there are any associated objects.
        #
        #   If using with the <tt>:through</tt> option, the association on the join model must be
        #   a #belongs_to, and the records which get deleted are the join records, rather than
        #   the associated records.
        #
        #   If using <tt>dependent: :destroy</tt> on a scoped association, only the scoped objects are destroyed.
        #   For example, if a Post model defines
        #   <tt>has_many :comments, -> { where published: true }, dependent: :destroy</tt> and <tt>destroy</tt> is
        #   called on a post, only published comments are destroyed. This means that any unpublished comments in the
        #   database would still contain a foreign key pointing to the now deleted post.
        # [:counter_cache]
        #   This option can be used to configure a custom named <tt>:counter_cache.</tt> You only need this option,
        #   when you customized the name of your <tt>:counter_cache</tt> on the #belongs_to association.
        # [:as]
        #   Specifies a polymorphic interface (See #belongs_to).
        # [:through]
        #   Specifies an association through which to perform the query. This can be any other type
        #   of association, including other <tt>:through</tt> associations. Options for <tt>:class_name</tt>,
        #   <tt>:primary_key</tt> and <tt>:foreign_key</tt> are ignored, as the association uses the
        #   source reflection.
        #
        #   If the association on the join model is a #belongs_to, the collection can be modified
        #   and the records on the <tt>:through</tt> model will be automatically created and removed
        #   as appropriate. Otherwise, the collection is read-only, so you should manipulate the
        #   <tt>:through</tt> association directly.
        #
        #   If you are going to modify the association (rather than just read from it), then it is
        #   a good idea to set the <tt>:inverse_of</tt> option on the source association on the
        #   join model. This allows associated records to be built which will automatically create
        #   the appropriate join model records when they are saved. (See the 'Association Join Models'
        #   section above.)
        # [:source]
        #   Specifies the source association name used by #has_many <tt>:through</tt> queries.
        #   Only use it if the name cannot be inferred from the association.
        #   <tt>has_many :subscribers, through: :subscriptions</tt> will look for either <tt>:subscribers</tt> or
        #   <tt>:subscriber</tt> on Subscription, unless a <tt>:source</tt> is given.
        # [:source_type]
        #   Specifies type of the source association used by #has_many <tt>:through</tt> queries where the source
        #   association is a polymorphic #belongs_to.
        # [:validate]
        #   When set to +true+, validates new objects added to association when saving the parent object. +true+ by default.
        #   If you want to ensure associated objects are revalidated on every update, use +validates_associated+.
        # [:autosave]
        #   If true, always save the associated objects or destroy them if marked for destruction,
        #   when saving the parent object. If false, never save or destroy the associated objects.
        #   By default, only save associated objects that are new records. This option is implemented as a
        #   +before_save+ callback. Because callbacks are run in the order they are defined, associated objects
        #   may need to be explicitly saved in any user-defined +before_save+ callbacks.
        #
        #   Note that NestedAttributes::ClassMethods#accepts_nested_attributes_for sets
        #   <tt>:autosave</tt> to <tt>true</tt>.
        # [:inverse_of]
        #   Specifies the name of the #belongs_to association on the associated object
        #   that is the inverse of this #has_many association. Does not work in combination
        #   with <tt>:through</tt> or <tt>:as</tt> options.
        #   See ActiveRecord::Associations::ClassMethods's overview on Bi-directional associations for more detail.
        # [:extend]
        #   Specifies a module or array of modules that will be extended into the association object returned.
        #   Useful for defining methods on associations, especially when they should be shared between multiple
        #   association objects.
        #
        # Option examples:
        #   has_many :comments, -> { order("posted_on") }
        #   has_many :comments, -> { includes(:author) }
        #   has_many :people, -> { where(deleted: false).order("name") }, class_name: "Person"
        #   has_many :tracks, -> { order("position") }, dependent: :destroy
        #   has_many :comments, dependent: :nullify
        #   has_many :tags, as: :taggable
        #   has_many :reports, -> { readonly }
        #   has_many :subscribers, through: :subscriptions, source: :user
        def embeds_many(name, options = {}, &extension)
          reflection = Builder::EmbedsMany.build(self, name, options, &extension)
          Reflection.add_reflection self, name, reflection
        end

        # Specifies a one-to-one association with another class. This method should only be used
        # if the other class contains the foreign key. If the current class contains the foreign key,
        # then you should use #belongs_to instead. See also ActiveRecord::Associations::ClassMethods's overview
        # on when to use #has_one and when to use #belongs_to.
        #
        # The following methods for retrieval and query of a single associated object will be added:
        #
        # +association+ is a placeholder for the symbol passed as the +name+ argument, so
        # <tt>has_one :manager</tt> would add among others <tt>manager.nil?</tt>.
        #
        # [association(force_reload = false)]
        #   Returns the associated object. +nil+ is returned if none is found.
        # [association=(associate)]
        #   Assigns the associate object, extracts the primary key, sets it as the foreign key,
        #   and saves the associate object. To avoid database inconsistencies, permanently deletes an existing
        #   associated object when assigning a new one, even if the new one isn't saved to database.
        # [build_association(attributes = {})]
        #   Returns a new object of the associated type that has been instantiated
        #   with +attributes+ and linked to this object through a foreign key, but has not
        #   yet been saved.
        # [create_association(attributes = {})]
        #   Returns a new object of the associated type that has been instantiated
        #   with +attributes+, linked to this object through a foreign key, and that
        #   has already been saved (if it passed the validation).
        # [create_association!(attributes = {})]
        #   Does the same as <tt>create_association</tt>, but raises ActiveRecord::RecordInvalid
        #   if the record is invalid.
        #
        # === Example
        #
        # An Account class declares <tt>has_one :beneficiary</tt>, which will add:
        # * <tt>Account#beneficiary</tt> (similar to <tt>Beneficiary.where(account_id: id).first</tt>)
        # * <tt>Account#beneficiary=(beneficiary)</tt> (similar to <tt>beneficiary.account_id = account.id; beneficiary.save</tt>)
        # * <tt>Account#build_beneficiary</tt> (similar to <tt>Beneficiary.new("account_id" => id)</tt>)
        # * <tt>Account#create_beneficiary</tt> (similar to <tt>b = Beneficiary.new("account_id" => id); b.save; b</tt>)
        # * <tt>Account#create_beneficiary!</tt> (similar to <tt>b = Beneficiary.new("account_id" => id); b.save!; b</tt>)
        #
        # === Scopes
        #
        # You can pass a second argument +scope+ as a callable (i.e. proc or
        # lambda) to retrieve a specific record or customize the generated query
        # when you access the associated object.
        #
        # Scope examples:
        #   has_one :author, -> { where(comment_id: 1) }
        #   has_one :employer, -> { joins(:company) }
        #   has_one :dob, ->(dob) { where("Date.new(2000, 01, 01) > ?", dob) }
        #
        # === Options
        #
        # The declaration can also include an +options+ hash to specialize the behavior of the association.
        #
        # Options are:
        # [:class_name]
        #   Specify the class name of the association. Use it only if that name can't be inferred
        #   from the association name. So <tt>has_one :manager</tt> will by default be linked to the Manager class, but
        #   if the real class name is Person, you'll have to specify it with this option.
        # [:dependent]
        #   Controls what happens to the associated object when
        #   its owner is destroyed:
        #
        #   * <tt>:destroy</tt> causes the associated object to also be destroyed
        #   * <tt>:delete</tt> causes the associated object to be deleted directly from the database (so callbacks will not execute)
        #   * <tt>:nullify</tt> causes the foreign key to be set to +NULL+. Callbacks are not executed.
        #   * <tt>:restrict_with_exception</tt> causes an exception to be raised if there is an associated record
        #   * <tt>:restrict_with_error</tt> causes an error to be added to the owner if there is an associated object
        #
        #   Note that <tt>:dependent</tt> option is ignored when using <tt>:through</tt> option.
        # [:foreign_key]
        #   Specify the foreign key used for the association. By default this is guessed to be the name
        #   of this class in lower-case and "_id" suffixed. So a Person class that makes a #has_one association
        #   will use "person_id" as the default <tt>:foreign_key</tt>.
        # [:foreign_type]
        #   Specify the column used to store the associated object's type, if this is a polymorphic
        #   association. By default this is guessed to be the name of the polymorphic association
        #   specified on "as" option with a "_type" suffix. So a class that defines a
        #   <tt>has_one :tag, as: :taggable</tt> association will use "taggable_type" as the
        #   default <tt>:foreign_type</tt>.
        # [:primary_key]
        #   Specify the method that returns the primary key used for the association. By default this is +id+.
        # [:as]
        #   Specifies a polymorphic interface (See #belongs_to).
        # [:through]
        #   Specifies a Join Model through which to perform the query. Options for <tt>:class_name</tt>,
        #   <tt>:primary_key</tt>, and <tt>:foreign_key</tt> are ignored, as the association uses the
        #   source reflection. You can only use a <tt>:through</tt> query through a #has_one
        #   or #belongs_to association on the join model.
        # [:source]
        #   Specifies the source association name used by #has_one <tt>:through</tt> queries.
        #   Only use it if the name cannot be inferred from the association.
        #   <tt>has_one :favorite, through: :favorites</tt> will look for a
        #   <tt>:favorite</tt> on Favorite, unless a <tt>:source</tt> is given.
        # [:source_type]
        #   Specifies type of the source association used by #has_one <tt>:through</tt> queries where the source
        #   association is a polymorphic #belongs_to.
        # [:validate]
        #   When set to +true+, validates new objects added to association when saving the parent object. +false+ by default.
        #   If you want to ensure associated objects are revalidated on every update, use +validates_associated+.
        # [:autosave]
        #   If true, always save the associated object or destroy it if marked for destruction,
        #   when saving the parent object. If false, never save or destroy the associated object.
        #   By default, only save the associated object if it's a new record.
        #
        #   Note that NestedAttributes::ClassMethods#accepts_nested_attributes_for sets
        #   <tt>:autosave</tt> to <tt>true</tt>.
        # [:inverse_of]
        #   Specifies the name of the #belongs_to association on the associated object
        #   that is the inverse of this #has_one association. Does not work in combination
        #   with <tt>:through</tt> or <tt>:as</tt> options.
        #   See ActiveRecord::Associations::ClassMethods's overview on Bi-directional associations for more detail.
        # [:required]
        #   When set to +true+, the association will also have its presence validated.
        #   This will validate the association itself, not the id. You can use
        #   +:inverse_of+ to avoid an extra query during validation.
        #
        # Option examples:
        #   has_one :credit_card, dependent: :destroy  # destroys the associated credit card
        #   has_one :credit_card, dependent: :nullify  # updates the associated records foreign
        #                                                 # key value to NULL rather than destroying it
        #   has_one :last_comment, -> { order('posted_on') }, class_name: "Comment"
        #   has_one :project_manager, -> { where(role: 'project_manager') }, class_name: "Person"
        #   has_one :attachment, as: :attachable
        #   has_one :boss, -> { readonly }
        #   has_one :club, through: :membership
        #   has_one :primary_address, -> { where(primary: true) }, through: :addressables, source: :addressable
        #   has_one :credit_card, required: true
        def embeds_one(name, options = {})
          reflection = Builder::EmbedsOne.build(self, name, options)
          Reflection.add_reflection self, name, reflection
        end
      end
  end
end
