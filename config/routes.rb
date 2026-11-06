Rails.application.routes.draw do
  root to: redirect("/docs", status: 302)

  scope :health, controller: :health, as: :health, format: false do
    get :live
    get :ready
  end

  namespace :api, format: false do
    namespace :v1 do
      resources :books, param: :serial_number, only: %i[ index show create destroy ] do
        resources :borrowings, only: :create
      end

      resources :borrowings, only: :show do
        resource :return, only: :create, module: :borrowings
      end

      resources :readers, param: :card_number, only: %i[ index show create ]
    end
  end

  match "*path", to: "errors#unmatched_route", via: :all, format: false
end
