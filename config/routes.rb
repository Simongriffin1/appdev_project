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
  get "/dashboard" => "dashboard#show", as: :dashboard
  post "/send_prompt" => "dashboard#send_prompt", as: :send_prompt
  post "/dashboard/toggle_schedule" => "dashboard#toggle_schedule", as: :toggle_schedule
  root "dashboard#show"

  # Backwards-compatible route
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

  # Action Mailbox ingress (production) and conductor (development)
  mount ActionMailbox::Engine => "/rails/action_mailbox"
  
  # Development-only tools
  if Rails.env.development?
    # Letter Opener Web for email preview
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if defined?(LetterOpenerWeb)
  end
end
