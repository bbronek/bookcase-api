module Api
  module V1
    class ReaderSerializer < BaseSerializer
      attributes :card_number, :full_name, :email
    end
  end
end
