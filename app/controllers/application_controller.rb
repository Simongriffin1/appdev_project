class ApplicationController < ActionController::Base
  # Enable CSRF protection for security
  protect_from_forgery with: :exception

  # Authentication - require login by default
  before_action :authenticate_user!
  before_action :ensure_onboarding_complete, unless: -> { 
    controller_name == "settings" || 
    controller_name == "sessions" || 
    controller_name == "users" 
  }

  # Authentication helpers
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def authenticate_user!
    return if current_user
    redirect_to sign_in_path, alert: "You must sign in first."
  end

  helper_method :current_user

  private

  def ensure_onboarding_complete
    return if current_user.nil? || current_user.onboarding_complete?
    redirect_to settings_path, alert: "Please complete your settings first."
  end
end
