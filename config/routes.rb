Rails.application.routes.draw do
  # Authentication routes
  get "/sign_in" => "sessions#new", as: :sign_in
  post "/sign_in" => "sessions#create"
  delete "/sign_out" => "sessions#destroy", as: :sign_out

  # User sign-up
  resources :users, only: [:new, :create]

  # Settings
  get "/settings" => "settings#show", as: :settings
  patch "/settings" => "settings#update"

  # Dashboard (root)
  get "/dashboard" => "dashboard#show", as: :dashboard
  post "/send_prompt" => "dashboard#send_prompt", as: :send_prompt
  root "dashboard#show"
  
  # Manual prompt sending
  post "/dashboard/send_prompt" => "dashboard#send_prompt", as: :send_prompt

  # Prompts with generate action
  resources :prompts, only: [:index, :show] do
    post :generate, on: :collection, as: :generate
  end

  # Journal entries
  resources :journal_entries, only: [:index, :show, :new, :create]
  
  mount ActionMailbox::Engine => "/rails/conductor/action_mailbox" if Rails.env.development?

  post "/send_next_prompt" => "dashboard#send_next_prompt"



  # Topics
  resources :topics, only: [:index, :show]

  # Entry analyses (read-only)
  resources :entry_analyses, only: [:index, :show]

  # Email messages (read-only for debugging)
  resources :email_messages, only: [:index, :show]

  # Action Mailbox conductor (development only)
  if Rails.env.development?
    mount ActionMailbox::Engine => "/rails/conductor/action_mailbox"
  end
end
