# This class is inherited by the has_many and has_many_and_belongs_to_many association classes

module DuckRecord::Associations::Builder # :nodoc:
  class EmbedsMany < CollectionAssociation #:nodoc:
    def self.macro
      :embeds_many
    end
  end
end
