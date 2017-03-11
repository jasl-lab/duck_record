module DuckRecord
  module Translation
    include ActiveModel::Translation

    # Set the lookup ancestors for ActiveModel.
    def lookup_ancestors #:nodoc:
      klass = self
      classes = [klass]
      return classes if klass == DuckRecord::Base

      while klass != klass.base_class
        classes << klass = klass.superclass
      end
      classes
    end

    # Set the i18n scope to overwrite ActiveModel.
    def i18n_scope #:nodoc:
      :duck_record
    end
  end
end
