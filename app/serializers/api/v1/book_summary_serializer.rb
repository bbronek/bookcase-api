module Api
  module V1
    class BookSummarySerializer < BaseSerializer
      attributes :serial_number, :title
    end
  end
end
