Rails.application.routes.draw do
  # Authentication routes
  get "/sign_in" => "sessions#new"
  post "/sign_in" => "sessions#create"
  delete "/sign_out" => "sessions#destroy"

  # User sign-up
  resources :users, only: [:new, :create]

  # Dashboard (root)
  get "/dashboard" => "dashboard#show"
  root "dashboard#show"

  # Prompts with generate action
  resources :prompts do
    post :generate, on: :collection
  end

  # Journal entries
  resources :journal_entries

  # Topics
  resources :topics, only: [:index]

  # Entry analyses (read-only)
  resources :entry_analyses, only: [:index, :show]

  # Email messages (read-only for debugging)
  resources :email_messages, only: [:index, :show]
end
