module DuckRecord
  module Type
    class Date < ActiveModel::Type::Date
      include Internal::Timezone
    end
  end
end
