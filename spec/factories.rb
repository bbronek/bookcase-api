FactoryBot.define do
  factory :book do
    sequence(:serial_number) { |n| n.to_s.rjust(6, "0") }
    title { "Dune" }
    author { "Frank Herbert" }
  end

  factory :reader do
    sequence(:card_number) { |n| (100_000 + n).to_s }
    full_name { "Ada Lovelace" }
    sequence(:email) { |n| "reader#{n}@example.com" }
  end

  factory :borrowing do
    book
    reader
    borrowed_at { Time.current }
    due_on { borrowed_at.to_date + Borrowing::LOAN_PERIOD_DAYS }

    trait :returned do
      borrowed_at { 40.days.ago }
      returned_at { 20.days.ago }
    end
  end

  factory :reminder do
    borrowing
    kind { "upcoming" }
  end
end
