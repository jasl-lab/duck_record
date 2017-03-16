module DuckRecord
  module Type
    class DateTime < ActiveModel::Type::DateTime
      include Internal::Timezone
    end
  end
end
