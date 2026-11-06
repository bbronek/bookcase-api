FactoryBot.define do
  factory :book do
    sequence(:serial_number) { |n| format("%06d", 500_000 + n) }
    sequence(:title) { |n| "Book #{n}" }
    author { "Ursula K. Le Guin" }

    trait :withdrawn do
      withdrawn_at { 1.day.ago }
    end
  end

  factory :reader do
    sequence(:card_number) { |n| format("%06d", 600_000 + n) }
    sequence(:full_name) { |n| "Reader #{n}" }
    sequence(:email) { |n| "reader#{n}@example.com" }
  end

  factory :borrowing do
    book
    reader
    borrowed_at { Time.current }
    due_on { Borrowing.due_on_for(borrowed_at) }

    trait :due_soon do
      borrowed_at { Time.current + 3.days - Borrowing::PERIOD }
    end

    trait :due_today do
      borrowed_at { Time.current - Borrowing::PERIOD }
    end

    trait :returned do
      borrowed_at { 60.days.ago }
      returned_at { borrowed_at + 10.days }
    end
  end

  factory :reminder do
    borrowing
    kind { "upcoming" }

    trait :sent do
      sent_at { Time.current }
    end

  end
end
