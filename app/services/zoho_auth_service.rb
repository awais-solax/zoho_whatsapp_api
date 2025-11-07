require "net/http"
require "uri"
require "json"
require "openssl"

class ZohoAuthService
  OAUTH_BASE_URI = ENV.fetch("ZOHO_OAUTH_BASE_URI")

  def initialize
    @client_id     = ENV["ZOHO_CLIENT_ID"]
    @client_secret = ENV["ZOHO_CLIENT_SECRET"]
    @redirect_uri  = ENV["ZOHO_REDIRECT_URI"]
  end

  # Exchange authorization code for access token
  def exchange_code_for_token(code)
    uri = URI(OAUTH_BASE_URI)

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      "code"          => code,
      "client_id"     => @client_id,
      "client_secret" => @client_secret,
      "redirect_uri"  => @redirect_uri,
      "grant_type"    => "authorization_code"
    )

    response = make_request(uri, request)
    handle_token_response(response)
  end

  # Refresh access token using refresh token
  def refresh_access_token
    refresh_token = get_stored_refresh_token
    return { error: "No refresh token found" } unless refresh_token

    uri = URI(OAUTH_BASE_URI)

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      "refresh_token" => refresh_token,
      "client_id"     => @client_id,
      "client_secret" => @client_secret,
      "grant_type"    => "refresh_token"
    )

    response = make_request(uri, request)
    handle_token_response(response)
  end

  def get_stored_access_token
    redis.get("zoho_access_token")
  end

  private

  def handle_token_response(response)
    if response.is_a?(Net::HTTPSuccess)
      token_data = JSON.parse(response.body)
      store_tokens(token_data)
      token_data
    else
      { error: "Token request failed", details: JSON.parse(response.body) }
    end
  rescue JSON::ParserError
    { error: "Token request failed", details: response.body }
  rescue StandardError => e
    { error: "Token request failed", details: "#{e.class}: #{e.message}" }
  end

  def make_request(uri, request)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    # Enable SSL verification in production for security
    http.verify_mode = Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 30
    http.read_timeout = 30
    http.ssl_timeout = 30
    http.request(request)
  end

  def redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end

  def store_tokens(token_data)
    redis.setex("zoho_access_token", 3600, token_data["access_token"]) if token_data["access_token"]
    redis.set("zoho_refresh_token", token_data["refresh_token"]) if token_data["refresh_token"]
  end

  def get_stored_refresh_token
    redis.get("zoho_refresh_token")
  end
end
