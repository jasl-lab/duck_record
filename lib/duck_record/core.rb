require "thread"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/duplicable"
require "active_support/core_ext/string/filters"

module DuckRecord
  module Core
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      # Determines whether to use Time.utc (using :utc) or Time.local (using :local) when pulling
      # dates and times from the database. This is set to :utc by default.
      mattr_accessor :default_timezone, instance_writer: false
      self.default_timezone = :utc
    end

    module ClassMethods
      def allocate
        define_attribute_methods
        super
      end

      def inherited(child_class) # :nodoc:
        super
      end

      def initialize_generated_modules # :nodoc:
        generated_association_methods
      end

      def generated_association_methods
        @generated_association_methods ||= begin
          mod = const_set(:GeneratedAssociationMethods, Module.new)
          private_constant :GeneratedAssociationMethods
          include mod

          mod
        end
      end

      # Returns a string like 'Post(id:integer, title:string, body:text)'
      def inspect
        if abstract_class?
          "#{super}(abstract)"
        else
          super
        end
      end
    end

    # New objects can be instantiated as either empty (pass no construction parameter) or pre-set with
    # attributes but not yet saved (pass a hash with key names matching the associated table column names).
    # In both instances, valid attribute keys are determined by the column names of the associated table --
    # hence you can't have attributes that aren't part of the table columns.
    #
    # ==== Example:
    #   # Instantiates a single new object
    #   User.new(first_name: 'Jamie')
    def initialize(attributes = nil)
      self.class.define_attribute_methods
      @attributes = self.class._default_attributes.deep_dup

      init_internals
      initialize_internals_callback

      if attributes
        assign_attributes(attributes, force_write_readonly: true)
        clear_changes_information
      end

      yield self if block_given?
      _run_initialize_callbacks
    end

    # Initialize an empty model object from +coder+. +coder+ should be
    # the result of previously encoding an Active Record model, using
    # #encode_with.
    #
    #   class Post < DuckRecord::Base
    #   end
    #
    #   old_post = Post.new(title: "hello world")
    #   coder = {}
    #   old_post.encode_with(coder)
    #
    #   post = Post.allocate
    #   post.init_with(coder)
    #   post.title # => 'hello world'
    def init_with(coder)
      @attributes = self.class.yaml_encoder.decode(coder)

      init_internals

      self.class.define_attribute_methods

      yield self if block_given?

      _run_initialize_callbacks

      self
    end

    ##
    # :method: clone
    # Identical to Ruby's clone method.  This is a "shallow" copy.  Be warned that your attributes are not copied.
    # That means that modifying attributes of the clone will modify the original, since they will both point to the
    # same attributes hash. If you need a copy of your attributes hash, please use the #dup method.
    #
    #   user = User.first
    #   new_user = user.clone
    #   user.name               # => "Bob"
    #   new_user.name = "Joe"
    #   user.name               # => "Joe"
    #
    #   user.object_id == new_user.object_id            # => false
    #   user.name.object_id == new_user.name.object_id  # => true
    #
    #   user.name.object_id == user.dup.name.object_id  # => false

    ##
    # :method: dup
    # Duped objects have no id assigned and are treated as new records. Note
    # that this is a "shallow" copy as it copies the object's attributes
    # only, not its associations. The extent of a "deep" copy is application
    # specific and is therefore left to the application to implement according
    # to its need.
    # The dup method does not preserve the timestamps (created|updated)_(at|on).

    ##
    def initialize_dup(other) # :nodoc:
      @attributes = @attributes.deep_dup

      _run_initialize_callbacks

      super
    end

    # Populate +coder+ with attributes about this record that should be
    # serialized. The structure of +coder+ defined in this method is
    # guaranteed to match the structure of +coder+ passed to the #init_with
    # method.
    #
    # Example:
    #
    #   class Post < DuckRecord::Base
    #   end
    #   coder = {}
    #   Post.new.encode_with(coder)
    #   coder # => {"attributes" => {"id" => nil, ... }}
    def encode_with(coder)
      self.class.yaml_encoder.encode(@attributes, coder)
      coder["duck_record_yaml_version"] = 2
    end

    # Clone and freeze the attributes hash such that associations are still
    # accessible, even on destroyed records, but cloned models will not be
    # frozen.
    def freeze
      @attributes = @attributes.clone.freeze
      self
    end

    # Returns +true+ if the attributes hash has been frozen.
    def frozen?
      @attributes.frozen?
    end

    # Returns +true+ if the record is read only. Records loaded through joins with piggy-back
    # attributes will be marked as read only since they cannot be saved.
    def readonly?
      @readonly
    end

    # Marks this record as read only.
    def readonly!
      @readonly = true
    end

    # Returns the contents of the record as a nicely formatted string.
    def inspect
      # We check defined?(@attributes) not to issue warnings if the object is
      # allocated but not initialized.
      inspection = if defined?(@attributes) && @attributes
        self.class.attribute_names.collect do |name|
          if has_attribute?(name)
            "#{name}: #{attribute_for_inspect(name)}"
          end
        end.compact.join(", ")
      else
        "not initialized"
      end

      "#<#{self.class} #{inspection}>"
    end

    # Takes a PP and prettily prints this record to it, allowing you to get a nice result from <tt>pp record</tt>
    # when pp is required.
    def pretty_print(pp)
      return super if custom_inspect_method_defined?
      pp.object_address_group(self) do
        if defined?(@attributes) && @attributes
          pp.seplist(self.class.attribute_names, proc { pp.text "," }) do |attribute_name|
            attribute_value = read_attribute(attribute_name)
            pp.breakable " "
            pp.group(1) do
              pp.text attribute_name
              pp.text ":"
              pp.breakable
              pp.pp attribute_value
            end
          end
        else
          pp.breakable " "
          pp.text "not initialized"
        end
      end
    end

    # Returns a hash of the given methods with their names as keys and returned values as values.
    def slice(*methods)
      Hash[methods.flatten.map! { |method| [method, public_send(method)] }].with_indifferent_access
    end

    private

      # +Array#flatten+ will call +#to_ary+ (recursively) on each of the elements of
      # the array, and then rescues from the possible +NoMethodError+. If those elements are
      # +DuckRecord::Base+'s, then this triggers the various +method_missing+'s that we have,
      # which significantly impacts upon performance.
      #
      # So we can avoid the +method_missing+ hit by explicitly defining +#to_ary+ as +nil+ here.
      #
      # See also http://tenderlovemaking.com/2011/06/28/til-its-ok-to-return-nil-from-to_ary.html
      def to_ary
        nil
      end

      def init_internals
        @readonly = false
      end

      def initialize_internals_callback
      end

      def thaw
        if frozen?
          @attributes = @attributes.dup
        end
      end

      def custom_inspect_method_defined?
        self.class.instance_method(:inspect).owner != DuckRecord::Base.instance_method(:inspect).owner
      end
  end
end
