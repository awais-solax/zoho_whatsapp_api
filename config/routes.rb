require "sidekiq/web"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq Web UI (mount in development/staging only, or protect with authentication)
  mount Sidekiq::Web => "/sidekiq" if Rails.env.development?

  # Zoho
  get "zoho/oauth_callback", to: "zoho#oauth_callback"
  post "zoho/webhook", to: "zoho#webhook"
  get "zoho/fetch_records", to: "zoho#fetch_records"
  post "zoho/create_record", to: "zoho#create_record"

  # WhatsApp
  post "/webhook/whatsapp", to: "whatsapp#receive"
  get "/webhook/whatsapp", to: "whatsapp#verify"
end
