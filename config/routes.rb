Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }

  resource :onboarding, only: [:show, :create], controller: "onboarding"
  resources :learners, only: [:new, :create] do
    member do
      patch :activate
    end
  end

  root "dashboard#show"
  get "dashboard", to: "dashboard#show"
  resources :lesson_completions, only: [:create]
  resource :theme, only: [:update]
  resource :sidebar_preferences, only: [:update]

  get "up" => "rails/health#show", as: :rails_health_check
end
