# frozen_string_literal: true

class SendWhatsappPlainTextJob < ApplicationJob
  queue_as :default

  # Retry on network errors
  # Use polynomially_longer for ActiveJob (exponentially_longer is Sidekiq-specific)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ArgumentError

  def perform(recipient_phone:, message_text:)
    Rails.logger.info "🚀 Processing WhatsApp plain text message to #{recipient_phone}"

    response = WhatsappMessageSender.send_plain_text_message(
      recipient_phone: recipient_phone,
      message_text: message_text
    )

    response_code = response.code.to_i

    if response_code == 200
      Rails.logger.info "✅ WhatsApp plain text message sent successfully to #{recipient_phone}"
    else
      Rails.logger.error "❌ WhatsApp plain text message failed for #{recipient_phone}: #{response_code} - #{response.body}"
      # Re-raise to trigger retry mechanism for transient errors
      raise "WhatsApp API returned #{response_code}" if retryable_error?(response_code)
    end
  end

  private

  def retryable_error?(code)
    # Retry on 5xx errors (server errors) and 429 (rate limit)
    code >= 500 || code == 429
  end
end
