module DuckRecord::Associations::Builder # :nodoc:
  class HasMany < CollectionAssociation #:nodoc:
    def self.macro
      :has_many
    end
  end
end
