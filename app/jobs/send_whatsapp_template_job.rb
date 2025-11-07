# frozen_string_literal: true

class SendWhatsappTemplateJob < ApplicationJob
  queue_as :default

  # Retry on transient network errors, but not on invalid parameters
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ArgumentError

  TEMPLATE_PARAMS = {
    "application_stage_under_review" => %w[student_name id],
    "application_stage_admission_confirmed" => %w[student_name id],
    "application_stage_rejected" => %w[student_name id],
    "application_stage_waitlisted" => %w[student_name id],
    "application_stage_ineligible" => %w[student_name id],
    "application_stage_committee_interview" => %w[student_name], # only 1 param
    "application_stage_academic_interview" => %w[student_name id],
    "application_stage_shortlisted" => %w[student_name id],
    "application_status_update" => %w[student_name message_body]
  }.freeze

  def perform(template_name:, language:, components:, recipient_phone:)
    # Ensure only valid params are passed to the sender
    filtered_components = filter_components(template_name, components)

    sender = WhatsappMessageSender.new(
      template_name: template_name,
      language: language,
      components: filtered_components.symbolize_keys,
      recipient_phone: recipient_phone
    )

    response = sender.send_message
    response_code = response.code.to_i

    unless response_code == 200
      raise "WhatsApp API returned #{response_code}" if retryable_error?(response_code)
    end
  end

  private

  # Only keep parameters that belong to this template
  def filter_components(template_name, components)
    allowed_keys = TEMPLATE_PARAMS[template_name] || []
    components.to_h.slice(*allowed_keys.map(&:to_sym))
  end

  def retryable_error?(code)
    # Retry only for server or rate limit errors
    code >= 500 || code == 429
  end
end
