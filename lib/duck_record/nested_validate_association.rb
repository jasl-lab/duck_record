module DuckRecord
  # = Active Record Autosave Association
  #
  # AutosaveAssociation is a module that takes care of automatically saving
  # associated records when their parent is saved. In addition to saving, it
  # also destroys any associated records that were marked for destruction.
  # (See #mark_for_destruction and #marked_for_destruction?).
  #
  # Saving of the parent, its associations, and the destruction of marked
  # associations, all happen inside a transaction. This should never leave the
  # database in an inconsistent state.
  #
  # If validations for any of the associations fail, their error messages will
  # be applied to the parent.
  #
  # Note that it also means that associations marked for destruction won't
  # be destroyed directly. They will however still be marked for destruction.
  #
  # Note that <tt>autosave: false</tt> is not same as not declaring <tt>:autosave</tt>.
  # When the <tt>:autosave</tt> option is not present then new association records are
  # saved but the updated association records are not saved.
  #
  # == Validation
  #
  # Child records are validated unless <tt>:validate</tt> is +false+.
  #
  # == Callbacks
  #
  # Association with autosave option defines several callbacks on your
  # model (before_save, after_create, after_update). Please note that
  # callbacks are executed in the order they were defined in
  # model. You should avoid modifying the association content, before
  # autosave callbacks are executed. Placing your callbacks after
  # associations is usually a good practice.
  #
  # === One-to-one Example
  #
  #   class Post < ActiveRecord::Base
  #     has_one :author, autosave: true
  #   end
  #
  # Saving changes to the parent and its associated model can now be performed
  # automatically _and_ atomically:
  #
  #   post = Post.find(1)
  #   post.title       # => "The current global position of migrating ducks"
  #   post.author.name # => "alloy"
  #
  #   post.title = "On the migration of ducks"
  #   post.author.name = "Eloy Duran"
  #
  #   post.save
  #   post.reload
  #   post.title       # => "On the migration of ducks"
  #   post.author.name # => "Eloy Duran"
  #
  # Destroying an associated model, as part of the parent's save action, is as
  # simple as marking it for destruction:
  #
  #   post.author.mark_for_destruction
  #   post.author.marked_for_destruction? # => true
  #
  # Note that the model is _not_ yet removed from the database:
  #
  #   id = post.author.id
  #   Author.find_by(id: id).nil? # => false
  #
  #   post.save
  #   post.reload.author # => nil
  #
  # Now it _is_ removed from the database:
  #
  #   Author.find_by(id: id).nil? # => true
  #
  # === One-to-many Example
  #
  # When <tt>:autosave</tt> is not declared new children are saved when their parent is saved:
  #
  #   class Post < ActiveRecord::Base
  #     has_many :comments # :autosave option is not declared
  #   end
  #
  #   post = Post.new(title: 'ruby rocks')
  #   post.comments.build(body: 'hello world')
  #   post.save # => saves both post and comment
  #
  #   post = Post.create(title: 'ruby rocks')
  #   post.comments.build(body: 'hello world')
  #   post.save # => saves both post and comment
  #
  #   post = Post.create(title: 'ruby rocks')
  #   post.comments.create(body: 'hello world')
  #   post.save # => saves both post and comment
  #
  # When <tt>:autosave</tt> is true all children are saved, no matter whether they
  # are new records or not:
  #
  #   class Post < ActiveRecord::Base
  #     has_many :comments, autosave: true
  #   end
  #
  #   post = Post.create(title: 'ruby rocks')
  #   post.comments.create(body: 'hello world')
  #   post.comments[0].body = 'hi everyone'
  #   post.comments.build(body: "good morning.")
  #   post.title += "!"
  #   post.save # => saves both post and comments.
  #
  # Destroying one of the associated models as part of the parent's save action
  # is as simple as marking it for destruction:
  #
  #   post.comments # => [#<Comment id: 1, ...>, #<Comment id: 2, ...]>
  #   post.comments[1].mark_for_destruction
  #   post.comments[1].marked_for_destruction? # => true
  #   post.comments.length # => 2
  #
  # Note that the model is _not_ yet removed from the database:
  #
  #   id = post.comments.last.id
  #   Comment.find_by(id: id).nil? # => false
  #
  #   post.save
  #   post.reload.comments.length # => 1
  #
  # Now it _is_ removed from the database:
  #
  #   Comment.find_by(id: id).nil? # => true
  module NestedValidateAssociation
    extend ActiveSupport::Concern

    module AssociationBuilderExtension #:nodoc:
      def self.build(model, reflection)
        model.send(:add_nested_validate_association_callbacks, reflection)
      end

      def self.valid_options
        []
      end
    end

    included do
      Associations::Builder::Association.extensions << AssociationBuilderExtension
      mattr_accessor :index_nested_attribute_errors, instance_writer: false
      self.index_nested_attribute_errors = false
    end

    module ClassMethods # :nodoc:
      private

      def define_non_cyclic_method(name, &block)
        return if method_defined?(name)
        define_method(name) do |*args|
          result = true; @_already_called ||= {}
          # Loop prevention for validation of associations
          unless @_already_called[name]
            begin
              @_already_called[name] = true
              result = instance_eval(&block)
            ensure
              @_already_called[name] = false
            end
          end

          result
        end
      end

      # Adds validation and save callbacks for the association as specified by
      # the +reflection+.
      #
      # For performance reasons, we don't check whether to validate at runtime.
      # However the validation and callback methods are lazy and those methods
      # get created when they are invoked for the very first time. However,
      # this can change, for instance, when using nested attributes, which is
      # called _after_ the association has been defined. Since we don't want
      # the callbacks to get defined multiple times, there are guards that
      # check if the save or validation methods have already been defined
      # before actually defining them.
      def add_nested_validate_association_callbacks(reflection)
        validation_method = :"validate_associated_records_for_#{reflection.name}"
        if reflection.validate? && !method_defined?(validation_method)
          if reflection.collection?
            method = :validate_collection_association
          else
            method = :validate_single_association
          end

          define_non_cyclic_method(validation_method) do
            send(method, reflection)
            # TODO: remove the following line as soon as the return value of
            # callbacks is ignored, that is, returning `false` does not
            # display a deprecation warning or halts the callback chain.
            true
          end
          validate validation_method
          after_validation :_ensure_no_duplicate_errors
        end
      end
    end

    private

    # Validate the association if <tt>:validate</tt> or <tt>:autosave</tt> is
    # turned on for the association.
    def validate_single_association(reflection)
      association = association_instance_get(reflection.name)
      record      = association&.reader
      association_valid?(reflection, record) if record
    end

    # Validate the associated records if <tt>:validate</tt> or
    # <tt>:autosave</tt> is turned on for the association specified by
    # +reflection+.
    def validate_collection_association(reflection)
      if association = association_instance_get(reflection.name)
        if records = association.target
          records.each_with_index { |record, index| association_valid?(reflection, record, index) }
        end
      end
    end

    # Returns whether or not the association is valid and applies any errors to
    # the parent, <tt>self</tt>, if it wasn't. Skips any <tt>:autosave</tt>
    # enabled records if they're marked_for_destruction? or destroyed.
    def association_valid?(reflection, record, index = nil)
      unless valid = record.valid?
        indexed_attribute = !index.nil? && (reflection.options[:index_errors] || DuckRecord::Base.index_nested_attribute_errors)

        record.errors.each do |attribute, message|
          attribute = normalize_reflection_attribute(indexed_attribute, reflection, index, attribute)
          errors[attribute] << message
          errors[attribute].uniq!
        end

        record.errors.details.each_key do |attribute|
          reflection_attribute =
            normalize_reflection_attribute(indexed_attribute, reflection, index, attribute).to_sym

          record.errors.details[attribute].each do |error|
            errors.details[reflection_attribute] << error
            errors.details[reflection_attribute].uniq!
          end
        end
      end
      valid
    end

    def normalize_reflection_attribute(indexed_attribute, reflection, index, attribute)
      if indexed_attribute
        "#{reflection.name}[#{index}].#{attribute}"
      else
        "#{reflection.name}.#{attribute}"
      end
    end

    def _ensure_no_duplicate_errors
      errors.messages.each_key do |attribute|
        errors[attribute].uniq!
      end
    end
  end
end
