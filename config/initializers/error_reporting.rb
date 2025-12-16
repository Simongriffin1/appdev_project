# Error Reporting Configuration
# 
# This initializer sets up error reporting for production.
# Currently uses Rails logger, but can be extended with Rollbar, Sentry, etc.

Rails.application.config.after_initialize do
  # Configure Rollbar if available and configured
  if defined?(Rollbar) && ENV["ROLLBAR_ACCESS_TOKEN"].present?
    Rollbar.configure do |config|
      config.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
      config.environment = Rails.env
      config.enabled = Rails.env.production?
    end
    Rails.logger.info "Rollbar error reporting configured"
  end

  # Set up global exception handler for unhandled exceptions
  if Rails.env.production?
    Rails.application.config.exceptions_app = ->(env) do
      exception = env["action_dispatch.exception"]
      
      # Log the error
      Rails.logger.error "Unhandled exception: #{exception.class} - #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n") if exception.respond_to?(:backtrace)
      
      # Report to error service if configured
      if defined?(Rollbar) && ENV["ROLLBAR_ACCESS_TOKEN"].present?
        Rollbar.error(exception, env)
      end
      
      # Render error page
      ActionDispatch::PublicException.new(Rails.public_path).call(env)
    end
  end
end
