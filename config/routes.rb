Rails.application.routes.draw do
  root "home#index"
  get "up" => "rails/health#show", as: :rails_health_check

  # Organizer dashboard: private, unguessable token.
  scope "/o/:token", as: :organizer do
    get "", to: "organizer#show", as: ""
    patch "", to: "organizer#update"
    post "recompute", to: "organizer#recompute", as: :recompute
  end

  # Friend invite page: one private, unguessable token per friend.
  scope "/i/:token", as: :invite do
    get "", to: "invites#show", as: ""
    resources :windows, only: %i[create update destroy] do
      patch :condition, on: :member
    end
    post "days/:date", to: "days#create", as: :day
    delete "days/:date", to: "days#destroy"
  end
end
