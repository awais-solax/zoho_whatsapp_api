# frozen_string_literal: true

class SendWhatsappTemplateJob < ApplicationJob
  queue_as :default

  # Retry on transient network errors, but not on invalid parameters
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ArgumentError

  TEMPLATE_PARAMS = {
    en: {
      "application_stage_under_review"          => %i[student_name id],
      "application_stage_committee_interview"  => %i[student_name],
      "application_stage_academic_interview"   => %i[student_name id],
      "application_stage_shortlisted"          => %i[student_name id],
      "application_stage_rejected"             => %i[student_name id],
      "application_stage_waitlisted"           => %i[student_name id],
      "application_stage_admission_confirmed"  => %i[student_name id],
      "application_stage_ineligible"           => %i[student_name id],
      "application_status_update"              => %i[student_name message_body]
    },
    fa: {  # Dari
      "application_stage_under_review_fa"          => %i[student_name id],
      "application_stage_committee_interview_fa"  => %i[student_name],
      "application_stage_academic_interview_fa"   => %i[student_name id],
      "application_stage_shortlisted_fa"          => %i[student_name id],
      "application_stage_rejected_fa"             => %i[student_name id],
      "application_stage_waitlisted_fa"           => %i[student_name id],
      "application_stage_admission_confirmed_fa"  => %i[student_name id],
      "application_stage_ineligible_fa"           => %i[student_name id]
    },
    ps_AF: {  # Pashto
      "application_stage_under_review_ps"          => %i[student_name id],
      "application_stage_committee_interview_ps"  => %i[student_name],
      "application_stage_academic_interview_ps"   => %i[student_name id],
      "application_stage_shortlisted_ps"          => %i[student_name id],
      "application_stage_rejected_ps"             => %i[student_name id],
      "application_stage_waitlisted_ps"           => %i[student_name id],
      "application_stage_admission_confirmed_ps"  => %i[student_name id],
      "application_stage_ineligible_ps"           => %i[student_name id]
    }
  }.freeze


  def perform(template_name:, language:, components:, recipient_phone:)
    # Ensure only valid params are passed to the sender
    filtered_components = filter_components(template_name, components, language)

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
  def filter_components(template_name, components, language)
    lang_key = language.to_s.downcase.to_sym
    allowed_keys = TEMPLATE_PARAMS.dig(lang_key, template_name) || []
    components.to_h.slice(*allowed_keys)
  end


  def retryable_error?(code)
    # Retry only for server or rate limit errors
    code >= 500 || code == 429
  end
end
