class ZohoCrmService
  include HTTParty
  base_uri ENV.fetch("ZOHO_BASE_URI")

  def initialize
    @auth_service = ZohoAuthService.new
  end

  def get_records(module_name, params = {})
    access_token = @auth_service.get_stored_access_token
    return { error: "No access token found" } unless access_token

    response = self.class.get(
      "/crm/v2/#{module_name}",
      headers: { "Authorization" => "Zoho-oauthtoken #{access_token}" },
      query: params,
      timeout: 30
    )

    handle_response(response) || retry_with_refresh(:get_records, module_name, params)
  rescue => e
    { error: "Failed to fetch records", details: e.message }
  end


  private

  def handle_response(response)
    return response.parsed_response if response.success?
    return nil if response.code == 401 # force refresh

    { error: "API request failed", details: response.parsed_response }
  end

  def retry_with_refresh(method_name, *args)
    refresh = @auth_service.refresh_access_token
    return refresh if refresh[:error]

    send(method_name, *args)
  end
end
