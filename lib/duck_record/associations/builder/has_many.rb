module DuckRecord::Associations::Builder # :nodoc:
  class HasMany < CollectionAssociation #:nodoc:
    def self.macro
      :has_many
    end

    def self.valid_options(_options)
      super + [:primary_key, :through, :source, :source_type, :join_table, :foreign_type, :index_errors]
    end
  end
end
