# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :api_key, :api_token, :openai_api_key, :postmark_api_token, :password_digest
]

# Filter sensitive environment variables from logs
Rails.application.config.filter_parameters += [
  /OPENAI_API_KEY/i,
  /POSTMARK_API_TOKEN/i,
  /SMTP_PASSWORD/i,
  /SECRET_KEY_BASE/i
]
