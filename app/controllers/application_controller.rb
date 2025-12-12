class ApplicationController < ActionController::Base
  # Enable CSRF protection for security
  protect_from_forgery with: :exception

  # Authentication - require login by default
  before_action :authenticate_user!

  # Authentication helpers
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    return if current_user
    redirect_to sign_in_path, alert: "You must sign in first."
  end

  helper_method :current_user
end
