class WhatsappController < ApplicationController
  skip_before_action :verify_authenticity_token

  def verify
    mode         = params["hub.mode"]
    token        = params["hub.verify_token"]
    challenge    = params["hub.challenge"]
    verify_token = ENV.fetch("WHATSAPP_VERIFY_TOKEN")

    if mode == "subscribe" && token == verify_token
      render plain: challenge, status: :ok
    else
      render plain: "Verification failed", status: :forbidden
    end
  end


  def receive
    parser = WebhookParser.new(request)
    data = parser.parse

    if parser.incoming_message?(data)
      process_incoming_message(parser, data)
    end

    render json: { status: "ok" }, status: :ok
  rescue => e
    Rails.logger.error e.full_message
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def process_incoming_message(parser, data)
    parsed = parser.extract_message_data(data)
    message, value = parsed[:message], parsed[:value]
    return unless message&.dig(:type) == "text"

    sender_phone = parser.extract_sender_phone(value, message)
    return unless sender_phone.present?

    send_student_reply(sender_phone)
  rescue => e
    Rails.logger.error e.full_message
  end

  def send_student_reply(recipient_phone)
    reply_message = I18n.t("student_reply_message")

    # Enqueue the job instead of sending directly
    SendWhatsappPlainTextJob.perform_later(
      recipient_phone: recipient_phone,
      message_text: reply_message
    )

    Rails.logger.info "📥 Enqueued student reply message job for #{recipient_phone}"
  rescue => e
    Rails.logger.error "❌ Error enqueuing student reply message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
