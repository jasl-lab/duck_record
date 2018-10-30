require "active_support/core_ext/hash/indifferent_access"

module DuckRecord
  # == Single table inheritance
  #
  # Active Record allows inheritance by storing the name of the class in a column that by
  # default is named "type" (can be changed by overwriting <tt>Base.inheritance_column</tt>).
  # This means that an inheritance looking like this:
  #
  #   class Company < DuckRecord::Base; end
  #   class Firm < Company; end
  #   class Client < Company; end
  #   class PriorityClient < Client; end
  #
  # When you do <tt>Firm.create(name: "37signals")</tt>, this record will be saved in
  # the companies table with type = "Firm". You can then fetch this row again using
  # <tt>Company.where(name: '37signals').first</tt> and it will return a Firm object.
  #
  # Be aware that because the type column is an attribute on the record every new
  # subclass will instantly be marked as dirty and the type column will be included
  # in the list of changed attributes on the record. This is different from non
  # Single Table Inheritance(STI) classes:
  #
  #   Company.new.changed? # => false
  #   Firm.new.changed?    # => true
  #   Firm.new.changes     # => {"type"=>["","Firm"]}
  #
  # If you don't have a type column defined in your table, single-table inheritance won't
  # be triggered. In that case, it'll work just like normal subclasses with no special magic
  # for differentiating between them or reloading the right type with find.
  #
  # Note, all the attributes for all the cases are kept in the same table. Read more:
  # http://www.martinfowler.com/eaaCatalog/singleTableInheritance.html
  #
  module Inheritance
    extend ActiveSupport::Concern

    module ClassMethods
      # Determines if one of the attributes passed in is the inheritance column,
      # and if the inheritance column is attr accessible, it initializes an
      # instance of the given subclass instead of the base class.
      def new(*args, &block)
        if abstract_class? || self == Base
          raise NotImplementedError, "#{self} is an abstract class and cannot be instantiated."
        end

        super
      end

      # Returns the class descending directly from DuckRecord::Base, or
      # an abstract class, if any, in the inheritance hierarchy.
      #
      # If A extends DuckRecord::Base, A.base_class will return A. If B descends from A
      # through some arbitrarily deep hierarchy, B.base_class will return A.
      #
      # If B < A and C < B and if A is an abstract_class then both B.base_class
      # and C.base_class would return B as the answer since A is an abstract_class.
      def base_class
        unless self < Base
          raise DuckRecordError, "#{name} doesn't belong in a hierarchy descending from DuckRecord"
        end

        if superclass == Base || superclass.abstract_class?
          self
        else
          superclass.base_class
        end
      end

      # Set this to true if this is an abstract class (see <tt>abstract_class?</tt>).
      # If you are using inheritance with DuckRecord and don't want child classes
      # to utilize the implied STI table name of the parent class, this will need to be true.
      # For example, given the following:
      #
      #   class SuperClass < DuckRecord::Base
      #     self.abstract_class = true
      #   end
      #   class Child < SuperClass
      #     self.table_name = 'the_table_i_really_want'
      #   end
      #
      #
      # <tt>self.abstract_class = true</tt> is required to make <tt>Child<.find,.create, or any Arel method></tt> use <tt>the_table_i_really_want</tt> instead of a table called <tt>super_classes</tt>
      #
      attr_accessor :abstract_class

      # Returns whether this class is an abstract class or not.
      def abstract_class?
        defined?(@abstract_class) && @abstract_class == true
      end

      def inherited(subclass)
        subclass.instance_variable_set(:@_type_candidates_cache, Concurrent::Map.new)
        super
      end

      protected

        # Returns the class type of the record using the current module as a prefix. So descendants of
        # MyApp::Business::Account would appear as MyApp::Business::AccountSubclass.
        def compute_type(type_name)
          if type_name.start_with?("::".freeze)
            # If the type is prefixed with a scope operator then we assume that
            # the type_name is an absolute reference.
            ActiveSupport::Dependencies.constantize(type_name)
          else
            type_candidate = @_type_candidates_cache[type_name]
            if type_candidate && type_constant = ActiveSupport::Dependencies.safe_constantize(type_candidate)
              return type_constant
            end

            # Build a list of candidates to search for
            candidates = []
            type_name.scan(/::|$/) { candidates.unshift "#{$`}::#{type_name}" }
            candidates << type_name

            candidates.each do |candidate|
              constant = ActiveSupport::Dependencies.safe_constantize(candidate)
              if candidate == constant.to_s
                @_type_candidates_cache[type_name] = candidate
                return constant
              end
            end

            raise NameError.new("uninitialized constant #{candidates.first}", candidates.first)
          end
        end
    end
  end
end
