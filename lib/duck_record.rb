require "active_support"
require "active_support/rails"
require "active_model"

require "core_ext/array_without_blank"

require "duck_record/type"
require "duck_record/attribute_set"

module DuckRecord
  extend ActiveSupport::Autoload

  autoload :Attribute
  autoload :Base
  autoload :Callbacks
  autoload :Core
  autoload :Inheritance
  autoload :ModelSchema
  autoload :NestedAttributes
  autoload :ReadonlyAttributes
  autoload :Reflection
  autoload :Serialization
  autoload :Translation
  autoload :Validations

  eager_autoload do
    autoload :DuckRecordError, "duck_record/errors"

    autoload :Associations
    autoload :AttributeAssignment
    autoload :AttributeMethods
    autoload :NestedValidateAssociation
  end

  module AttributeMethods
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :BeforeTypeCast
      autoload :Dirty
      autoload :Read
      autoload :Write
    end
  end

  def self.eager_load!
    super

    DuckRecord::Associations.eager_load!
    DuckRecord::AttributeMethods.eager_load!
  end
end

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.dirname(__FILE__) + "/duck_record/locale/en.yml"
end
