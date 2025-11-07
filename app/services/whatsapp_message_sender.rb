class WhatsappMessageSender
  WHATSAPP_API_URL = ENV.fetch("WHATSAPP_BASE_URL")
  PHONE_NUMBER_ID  = ENV.fetch("WHATSAPP_SERVICE_NUMBER_ID")
  ACCESS_TOKEN     = ENV.fetch("WHATSAPP_KEY")

  def initialize(template_name:, language:, components:, recipient_phone:)
    @template_name   = template_name
    @language        = language
    @components      = components
    @recipient_phone = recipient_phone
  end

  def send_message
    response = send_template_message
    code = response.code.to_i

    if code == 404 || template_missing?(response)
      Rails.logger.error "❌ Template '#{@template_name}' not found. Message not sent to #{@recipient_phone}"
    elsif code == 200
      Rails.logger.info "✅ Template '#{@template_name}' sent successfully to #{@recipient_phone}"
    else
      Rails.logger.error "❌ WhatsApp API returned error #{code} for template '#{@template_name}': #{response.body}"
    end

    response
  rescue => e
    Rails.logger.error "❌ Exception in send_message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def send_template_message
    uri  = URI("#{WHATSAPP_API_URL}/#{PHONE_NUMBER_ID}/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE

    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{ACCESS_TOKEN}"
    }

    # -------------------------
    # ✅ NAMED PARAMETER SUPPORT
    # -------------------------
    body_params = []
    @components.each do |key, value|
      next if value.blank?

      body_params << {
        type: "text",
        parameter_name: key.to_s, # << Must match the template variable name in Meta
        text: value.to_s.strip
      }
    end

    components = body_params.any? ? [ { type: "body", parameters: body_params } ] : []

    payload = {
      messaging_product: "whatsapp",
      to: @recipient_phone,
      type: "template",
      template: {
        name: @template_name,
        language: { code: @language },
        components: components
      }
    }

    Rails.logger.info "📤 WhatsApp API Request:"
    Rails.logger.info "   URL: #{uri}"
    Rails.logger.info "   Template: #{@template_name}"
    Rails.logger.info "   Language: #{@language}"
    Rails.logger.info "   Payload: #{JSON.pretty_generate(payload)}"

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = payload.to_json
    response = http.request(request)

    Rails.logger.info "📥 WhatsApp API Response:"
    Rails.logger.info "   Status: #{response.code}"
    Rails.logger.info "   Body: #{response.body[0..500]}"

    response
  end

  def template_missing?(response)
    body = JSON.parse(response.body) rescue {}
    body.dig("error", "error_data", "details")&.include?("template name") ||
      body.dig("error", "message")&.include?("template name")
  end

  # Used to send plain text messages (non-template)
  def self.send_plain_text_message(recipient_phone:, message_text:)
    uri  = URI("#{WHATSAPP_API_URL}/#{PHONE_NUMBER_ID}/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE

    headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{ACCESS_TOKEN}"
    }

    payload = {
      messaging_product: "whatsapp",
      to: recipient_phone,
      type: "text",
      text: { body: message_text }
    }

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = payload.to_json
    response = http.request(request)

    if response.code.to_i == 200
      Rails.logger.info "✅ Plain text message sent successfully to #{recipient_phone}"
    else
      Rails.logger.error "❌ Plain text message failed: #{response.code} - #{response.body}"
    end

    response
  rescue => e
    Rails.logger.error "❌ Exception in send_plain_text_message: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
