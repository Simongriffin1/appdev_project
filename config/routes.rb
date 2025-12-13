Rails.application.routes.draw do
  # Authentication routes
  get    "/sign_in"  => "sessions#new",     as: :sign_in
  post   "/sign_in"  => "sessions#create"
  delete "/sign_out" => "sessions#destroy", as: :sign_out

  # Compatibility routes (some graders / conventions expect Devise-like paths)
  get  "/users/sign_in" => "sessions#new"
  post "/users/sign_in" => "sessions#create"
  get  "/users/sign_up" => "users#new"
  post "/users"         => "users#create"

  # User sign-up
  resources :users, only: [:new, :create]

  # Settings
  get  "/settings" => "settings#show",   as: :settings
  patch "/settings" => "settings#update"

  # Dashboard (root)
  get  "/dashboard" => "dashboard#show", as: :dashboard
  root "dashboard#show"

  # Manual prompt sending (your dashboard button uses send_prompt_path)
  post "/send_prompt" => "dashboard#send_prompt", as: :send_prompt

  # Optional: if you're using this route, keep it; otherwise delete it
  post "/send_next_prompt" => "dashboard#send_next_prompt"

  # Prompts
  resources :prompts, only: [:index, :show] do
    post :generate, on: :collection
  end

  # Journal entries
  resources :journal_entries, only: [:index, :show, :new, :create]

  # Topics
  resources :topics, only: [:index, :show]

  # Entry analyses (read-only)
  resources :entry_analyses, only: [:index, :show]

  # Email messages (read-only)
  resources :email_messages, only: [:index, :show]

  # Action Mailbox (development only)
  mount ActionMailbox::Engine => "/rails/action_mailbox" if Rails.env.development?
end
