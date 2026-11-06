module Membership
  class ReadersQuery
    def self.call(after:, limit:) = Page.of(Reader.all, ordered_by: :card_number, after:, limit:)
  end
end
