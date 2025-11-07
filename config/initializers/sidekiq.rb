# frozen_string_literal: true

# Ensure ActiveJob adapter is loaded
require "sidekiq/rails" if defined?(Rails)

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Ensure Rails environment is loaded
  config.on(:startup) do
    Rails.logger.info "Sidekiq server started with Rails environment"
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end

# Optional: Configure error handling
Sidekiq.configure_server do |config|
  config.death_handlers << ->(job, _ex) do
    Rails.logger.error "Job #{job['class']} failed permanently: #{job['error_message']}"
  end
end
