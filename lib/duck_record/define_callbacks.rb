module DuckRecord
  # This module exists because `DuckRecord::AttributeMethods::Dirty` needs to
  # define callbacks, but continue to have its version of `save` be the super
  # method of `DuckRecord::Callbacks`. This will be removed when the removal
  # of deprecated code removes this need.
  module DefineCallbacks
    extend ActiveSupport::Concern

    CALLBACKS = [
      :after_initialize, :before_validation, :after_validation,
    ]

    module ClassMethods # :nodoc:
      include ActiveModel::Callbacks
    end

    included do
      include ActiveModel::Validations::Callbacks

      define_model_callbacks :initialize, only: :after
    end
  end
end
