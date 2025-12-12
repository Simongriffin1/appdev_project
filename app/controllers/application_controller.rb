class ApplicationController < ActionController::Base
  # Enable CSRF protection for security
  protect_from_forgery with: :exception

  # Authentication helpers
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    redirect_to sign_in_path, alert: "Please sign in to continue." unless current_user
  end

  helper_method :current_user
end
