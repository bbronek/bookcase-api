Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # JSON regardless of the Accept header; this API has no other representation.
  scope defaults: { format: :json } do
    # Books are addressed by their serial number, readers by their card number: the identifiers staff actually use.
    resources :books, only: %i[ index show create destroy ], param: :serial_number
    resources :readers, only: %i[ index create ], param: :card_number
  end
end
