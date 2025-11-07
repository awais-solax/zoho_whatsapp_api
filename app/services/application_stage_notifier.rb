# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Handles sending application stage updates via WhatsApp template messages
class ApplicationStageNotifier
  def initialize(params)
    data = params[:data] || params.dig(:zoho, :data) || {}
    data = data.to_unsafe_h if data.respond_to?(:to_unsafe_h)
    @app_data = data.deep_symbolize_keys
  end

  def call
    stage          = @app_data[:stage]
    applicant_name = @app_data[:applicant_name]
    phone_number   = @app_data[:contact_number]
    preferred_lang = @app_data[:preferred_language] || "English"

    return if stage.blank? || phone_number.blank?

    formatted_phone = format_phone_number(phone_number)
    return if formatted_phone.blank?

    template_name, lang_code = get_template_name_and_language(stage, preferred_lang)
    return if template_name.blank?

    send_whatsapp_message(formatted_phone, applicant_name, template_name, lang_code)
  rescue => e
    Rails.logger.error "[ApplicationStageNotifier] #{e.message}\n#{e.backtrace.join("\n")}"
  end

  private

  def send_whatsapp_message(phone, name, template_name, lang_code)
    components = {
      student_name: name,
      id: application_id
    }.compact

    Rails.logger.info "📤 Preparing WhatsApp template job:"
    Rails.logger.info "   Template: #{template_name}"
    Rails.logger.info "   Language: #{lang_code}"
    Rails.logger.info "   Components: #{components.inspect}"
    Rails.logger.info "   Recipient: #{phone}"

    SendWhatsappTemplateJob.perform_later(
      template_name: template_name,
      language: lang_code,
      components: components,
      recipient_phone: phone
    )

    Rails.logger.info "📥 Enqueued WhatsApp template job: #{template_name} for #{name} (#{phone})"
  end

  def application_id
    @app_data[:application_id] || @app_data[:id]
  end

  def get_template_name_and_language(stage, preferred_language)
    lang_suffix, whatsapp_lang_code = map_language(preferred_language)
    stage_key = map_stage_to_key(stage)

    env_key = "WHATSAPP_TEMPLATE_#{stage_key}_#{lang_suffix.upcase}"
    template_name = ENV[env_key]

    [ template_name, whatsapp_lang_code ]
  end

  def map_language(preferred_language)
    lang_text = preferred_language.to_s.split("/").first&.strip&.downcase

    case lang_text
    when /dari|دری|farsi|فارسی/
      %w[fa fa]
    when /pashto|پښتو|پشتو/
      %w[ps ps_AF]
    else
      %w[en en]
    end
  end

  def map_stage_to_key(stage)
    case stage.to_s.downcase
    when /under review/        then "UNDER_REVIEW"
    when /academic interview/  then "ACADEMIC_INTERVIEW"
    when /committee interview/ then "COMMITTEE_INTERVIEW"
    when /rejected/            then "REJECTED"
    when /waitlist/            then "WAITLIST"
    when /confirmed/           then "ADMISSION_CONFIRMED"
    when /ineligible/          then "INELIGIBLE"
    when /shortlisted/         then "SHORTLISTED"
    else "UNDER_REVIEW"
    end
  end

  def format_phone_number(phone)
    digits = phone.to_s.gsub(/\D/, "")
    return if digits.blank?

    digits = digits.sub(/^0/, "92") unless digits.start_with?("92") || digits.start_with?("+")
    "+#{digits.delete_prefix("+")}"
  end
end
