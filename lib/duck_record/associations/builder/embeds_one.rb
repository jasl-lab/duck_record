# This class is inherited by the has_one and belongs_to association classes

module DuckRecord::Associations::Builder # :nodoc:
  class EmbedsOne < SingularAssociation #:nodoc:
    def self.macro
      :embeds_one
    end
  end
end
