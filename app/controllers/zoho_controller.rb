class ZohoController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :webhook ]

  def webhook
    Rails.logger.info "📩 Zoho Webhook received: #{params.inspect}"

    module_name = params.dig(:zoho, :module) || params[:module]

    if module_name == "Applications"
      ApplicationStageNotifier.new(params).call
    else
      Rails.logger.info "⚠️ Unhandled module: #{module_name}"
    end

    render json: { status: "success" }, status: :ok

  rescue StandardError => e
    Rails.logger.error "❌ Zoho Webhook error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: e.message }, status: :ok
  end
end
