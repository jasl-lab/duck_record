# frozen_string_literal: true
require "active_support/core_ext/module/attribute_accessors"
require "duck_record/attribute_mutation_tracker"

module DuckRecord
  module AttributeMethods
    module Dirty # :nodoc:
      extend ActiveSupport::Concern

      include ActiveModel::Dirty

      def initialize_dup(other) # :nodoc:
        super
        @attributes = self.class._default_attributes.map do |attr|
          attr.with_value_from_user(@attributes.fetch_value(attr.name))
        end
        @mutation_tracker = nil
      end

      def changes_applied
        @previous_mutation_tracker = mutation_tracker
        @changed_attributes = HashWithIndifferentAccess.new
        store_original_attributes
      end

      def clear_changes_information
        @previous_mutation_tracker = nil
        @changed_attributes = HashWithIndifferentAccess.new
        store_original_attributes
      end

      def raw_write_attribute(attr_name, *)
        result = super
        clear_attribute_change(attr_name)
        result
      end

      def clear_attribute_changes(attr_names)
        super
        attr_names.each do |attr_name|
          clear_attribute_change(attr_name)
        end
      end

      def changed_attributes
        # This should only be set by methods which will call changed_attributes
        # multiple times when it is known that the computed value cannot change.
        if defined?(@cached_changed_attributes)
          @cached_changed_attributes
        else
          super.reverse_merge(mutation_tracker.changed_values).freeze
        end
      end

      def changes
        cache_changed_attributes do
          super
        end
      end

      def previous_changes
        previous_mutation_tracker.changes
      end

      def attribute_changed_in_place?(attr_name)
        mutation_tracker.changed_in_place?(attr_name)
      end

      private

        def mutation_tracker
          unless defined?(@mutation_tracker)
            @mutation_tracker = nil
          end
          @mutation_tracker ||= AttributeMutationTracker.new(@attributes)
        end

        def changes_include?(attr_name)
          super || mutation_tracker.changed?(attr_name)
        end

        def clear_attribute_change(attr_name)
          mutation_tracker.forget_change(attr_name)
        end

        def store_original_attributes
          @attributes = @attributes.map(&:forgetting_assignment)
          @mutation_tracker = nil
        end

        def previous_mutation_tracker
          @previous_mutation_tracker ||= NullMutationTracker.instance
        end

        def cache_changed_attributes
          @cached_changed_attributes = changed_attributes
          yield
        ensure
          clear_changed_attributes_cache
        end

        def clear_changed_attributes_cache
          remove_instance_variable(:@cached_changed_attributes) if defined?(@cached_changed_attributes)
        end
    end
  end
end
