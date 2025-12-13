require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Allow server to be hosted on any URL
  config.hosts.clear

  # Allow better_errors and web_console to work in online IDE / Codespaces
  config.web_console.allowed_ips = "0.0.0.0/0"
  BetterErrors::Middleware.allow_ip! "0.0.0.0/0" if defined?(BetterErrors)

  # Auto-connect to database when rails console opens
  console do
    ActiveRecord::Base.connection
  end

  # Settings specified here will take precedence over those in config/application.rb.

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Change to :null_store to avoid any caching.
  config.cache_store = :memory_store

  # Store uploaded files on the local file system.
  config.active_storage.service = :local

  # Make template changes take effect immediately.
  config.action_mailer.perform_caching = false

  # Set localhost to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  # ----------------------------
  # Action Mailer (SMTP / Gmail)
  # ----------------------------
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false

  smtp_address  = ENV["SMTP_ADDRESS"]
  smtp_username = ENV["SMTP_USERNAME"]
  smtp_password = ENV["SMTP_PASSWORD"]

  if smtp_address.present? && smtp_username.present? && smtp_password.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: smtp_address,
      port: (ENV["SMTP_PORT"] || "587").to_i,
      domain: ENV["SMTP_DOMAIN"] || "gmail.com",
      user_name: smtp_username,
      password: smtp_password,
      authentication: (ENV["SMTP_AUTHENTICATION"] || "plain").to_sym,
      enable_starttls_auto: (ENV["SMTP_ENABLE_STARTTLS_AUTO"] || "true") == "true"
    }
  else
    # Fall back to file delivery if SMTP not configured
    config.action_mailer.delivery_method = :file
    config.action_mailer.file_settings = { location: Rails.root.join("tmp", "mail") }
    Rails.logger.warn "SMTP not configured. Set SMTP_ADDRESS/SMTP_USERNAME/SMTP_PASSWORD in .env to send real emails."
  end

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true
  config.active_job.queue_adapter = :solid_queue

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Allow POST authenticity on Codespaces in dev
  config.action_controller.forgery_protection_origin_check = false
end
