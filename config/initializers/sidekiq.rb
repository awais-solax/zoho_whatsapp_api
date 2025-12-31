# frozen_string_literal: true

# Ensure ActiveJob adapter is loaded

require "sidekiq/rails" if defined?(Rails)

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

redis_config =
  if redis_url.start_with?("rediss://")
    {
      url: redis_url,
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
    }
  else
    { url: redis_url }
  end

Sidekiq.configure_server do |config|
  config.redis = redis_config

  config.on(:startup) do
    Rails.logger.info "Sidekiq server started with Rails environment"
  end

  config.death_handlers << lambda { |job, _ex|
    Rails.logger.error "Job #{job['class']} failed permanently: #{job['error_message']}"
  }
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

