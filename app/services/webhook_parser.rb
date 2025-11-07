
  class WebhookParser
    def initialize(request)
      @request = request
    end

    def parse
      if json_request?
        parse_json_body
      else
        @request.params
      end.with_indifferent_access
    rescue JSON::ParserError
      @request.params
    end

    def incoming_message?(data)
      entry = data[:entry]
      return false unless entry.is_a?(Array) && entry.any?

      value = entry.first.dig(:changes, 0, :value)
      return false unless value

      messages = value[:messages]
      messages.is_a?(Array) && messages.any?
    end

    def extract_message_data(data)
      entry = data[:entry]&.first
      return unless entry

      value = entry.dig(:changes, 0, :value)
      return unless value

      {
        message: value[:messages]&.first,
        contacts: value[:contacts],
        value: value
      }
    end

    def extract_sender_phone(value, message)
      contacts = value[:contacts]
      if contacts.is_a?(Array) && contacts.any?
        contacts.first[:wa_id]
      else
        message[:from]
      end
    end

    private

    def json_request?
      @request.content_type&.include?("application/json")
    end

    def parse_json_body
      body = @request.body.read
      @request.body.rewind
      JSON.parse(body)
    end
  end
