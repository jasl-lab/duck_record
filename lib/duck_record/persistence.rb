module DuckRecord
  # = DuckRecord \Persistence
  module Persistence
    extend ActiveSupport::Concern

    def persisted?
      false
    end

    def destroyed?
      false
    end

    def new_record?
      true
    end

    # Returns an instance of the specified +klass+ with the attributes of the
    # current record. This is mostly useful in relation to single-table
    # inheritance structures where you want a subclass to appear as the
    # superclass. This can be used along with record identification in
    # Action Pack to allow, say, <tt>Client < Company</tt> to do something
    # like render <tt>partial: @client.becomes(Company)</tt> to render that
    # instance using the companies/company partial instead of clients/client.
    #
    # Note: The new instance will share a link to the same attributes as the original class.
    # Therefore the sti column value will still be the same.
    # Any change to the attributes on either instance will affect both instances.
    # If you want to change the sti column as well, use #becomes! instead.
    def becomes(klass)
      became = klass.new
      became.instance_variable_set("@attributes", @attributes)
      became.instance_variable_set("@mutation_tracker", @mutation_tracker) if defined?(@mutation_tracker)
      became.instance_variable_set("@changed_attributes", attributes_changed_by_setter)
      became.errors.copy!(errors)
      became
    end
  end
end
