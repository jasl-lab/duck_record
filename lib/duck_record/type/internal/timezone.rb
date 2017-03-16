module DuckRecord
  module Type
    module Internal
      module Timezone
        def is_utc?
          DuckRecord::Base.default_timezone == :utc
        end

        def default_timezone
          DuckRecord::Base.default_timezone
        end
      end
    end
  end
end
