module DuckRecord
  # = Active Record Errors
  #
  # Generic Active Record exception class.
  class DuckRecordError < StandardError
  end

  # Raised on attempt to update record that is instantiated as read only.
  class ReadOnlyRecord < DuckRecordError
  end

  # Raised when attribute has a name reserved by Active Record (when attribute
  # has name of one of Active Record instance methods).
  class DangerousAttributeError < DuckRecordError
  end

  # Raised when unknown attributes are supplied via mass assignment.
  UnknownAttributeError = ActiveModel::UnknownAttributeError

  # Raised when an error occurred while doing a mass assignment to an attribute through the
  # {DuckRecord::Base#attributes=}[rdoc-ref:AttributeAssignment#attributes=] method.
  # The exception has an +attribute+ property that is the name of the offending attribute.
  class AttributeAssignmentError < DuckRecordError
    attr_reader :exception, :attribute

    def initialize(message = nil, exception = nil, attribute = nil)
      super(message)
      @exception = exception
      @attribute = attribute
    end
  end

  # Raised when there are multiple errors while doing a mass assignment through the
  # {DuckRecord::Base#attributes=}[rdoc-ref:AttributeAssignment#attributes=]
  # method. The exception has an +errors+ property that contains an array of AttributeAssignmentError
  # objects, each corresponding to the error while assigning to an attribute.
  class MultiparameterAssignmentErrors < DuckRecordError
    attr_reader :errors

    def initialize(errors = nil)
      @errors = errors
    end
  end
end
