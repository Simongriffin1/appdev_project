ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Load environment variables from .env file (development/test only)
# Must be loaded after bundler but before Rails
if defined?(Dotenv)
  Dotenv.load(".env.local", ".env") if ENV["RAILS_ENV"] == "development" || ENV["RAILS_ENV"] == "test" || ENV["RAILS_ENV"].nil?
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
