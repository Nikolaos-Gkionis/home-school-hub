Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }

  root "pages#home"

  get "dashboard", to: "dashboard#show"
  get "insights", to: "insights#show"

  get "setup/years", to: "setup#years", as: :setup_years
  post "setup/years", to: "setup#save_years"
  get "setup/subjects", to: "setup#subjects", as: :setup_subjects
  post "setup/subjects", to: "setup#save_subjects"

  resources :learners, only: [ :new, :create, :destroy ] do
    member do
      patch :activate
    end
  end

  resources :invitations, only: [ :new, :create ]
  get "invitations/accept/:token", to: "invitations#accept", as: :accept_invitation

  post "lessons/:lesson_id/time", to: "lesson_time_logs#create", as: :lesson_time_log

  post "lessons/:lesson_id/section_views/:section_key", to: "lesson_progresses#record_section", as: :lesson_section_view
  post "lessons/:lesson_id/quiz_responses", to: "lesson_progresses#record_quiz", as: :lesson_quiz_responses
  get "lessons/:lesson_id/oak_assets/:type", to: "oak_assets#show", as: :lesson_oak_asset
  resources :lesson_completions, only: [ :create ]
  resource :theme, only: [ :update ]
  resource :sidebar_preferences, only: [ :update ]

  get "up" => "rails/health#show", as: :rails_health_check
end
