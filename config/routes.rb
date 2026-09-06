Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations"
  }

  root "pages#home"

  get "dashboard", to: "legacy_redirects#dashboard"
  get "insights", to: "insights#show"

  namespace :parent do
    get "dashboard", to: "dashboards#show"
    get "family", to: "families#show"
    get "children/:id", to: "families#child", as: :child
    get "children/:id/edit", to: "families#edit_child", as: :edit_child
    patch "children/:id", to: "families#update_child", as: :update_child
    delete "children/:id", to: "families#destroy_child", as: :remove_child
    resources :children, only: [] do
      resource :plan, only: [ :show, :update ], controller: "plans" do
        post :spread
      end
      resource :week, only: :show, controller: "week_calendars"
      resources :checkpoint_tests, only: [ :create, :show ] do
        member do
          get :answer_key
        end
      end
    end
  end

  namespace :child do
    get "dashboard", to: "dashboards#show"
    get "profile", to: "profiles#show"
    patch "profile", to: "profiles#update"
  end

  post "week_slots/swap", to: "week_slots#swap", as: :swap_week_slot
  post "week_slots/reset", to: "week_slots#reset", as: :reset_week_slot

  get "setup/years", to: "setup#years", as: :setup_years
  post "setup/years", to: "setup#save_years"
  get "setup/subjects", to: "setup#subjects", as: :setup_subjects
  post "setup/subjects", to: "setup#save_subjects"

  resources :learners, only: [ :new, :create, :destroy ] do
    member do
      patch :activate
    end
  end

  resources :invitations, only: [ :new, :create, :edit, :update, :destroy ] do
    post :resend, on: :member
  end
  get "invitations/accept/:token", to: "invitations#accept", as: :accept_invitation

  post "lessons/:lesson_id/time", to: "lesson_time_logs#create", as: :lesson_time_log

  post "lessons/:lesson_id/section_views/:section_key", to: "lesson_progresses#record_section", as: :lesson_section_view
  post "lessons/:lesson_id/quiz_responses", to: "lesson_progresses#record_quiz", as: :lesson_quiz_responses
  get "lessons/:lesson_id/oak_assets/:type", to: "oak_assets#show", as: :lesson_oak_asset
  resources :lesson_completions, only: [ :create ]
  resource :theme, only: [ :update ]
  resource :sidebar_preferences, only: [ :update ]

  get "up" => "rails/health#show", as: :rails_health_check

  # Dynamic PWA files from app/views/pwa/* (manifest + service worker).
  # Format defaults matter: browsers request these URLs without .json/.js.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }
end
