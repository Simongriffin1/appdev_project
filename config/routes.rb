Rails.application.routes.draw do
  # Authentication routes
  get "/sign_in", to: "sessions#new", as: :sign_in
  post "/sign_in", to: "sessions#create"
  delete "/sign_out", to: "sessions#destroy", as: :sign_out

  # Dashboard (homepage)
  root "dashboard#show"
  get "/dashboard", to: "dashboard#show", as: :dashboard

  # User sign-up
  resources :users, only: [:new, :create]

  # Prompts with generate action
  resources :prompts do
    post :generate, on: :collection
  end

  # Journal entries
  resources :journal_entries

  # Topics (read-only for now)
  resources :topics, only: [:index, :show]

  # Entry analyses (read-only)
  resources :entry_analyses, only: [:index, :show]

  # Email messages (read-only for debugging)
  resources :email_messages, only: [:index, :show]
end
