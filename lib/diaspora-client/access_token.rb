module DiasporaClient
  class AccessToken < ActiveRecord::Base
    belongs_to :user
    belongs_to :resource_server

    # Fetches the current or generates a new access token.
    #
    # @return [OAuth2::AccessToken]
    def token
      @token ||= OAuth2::AccessToken.new(resource_server.client, access_token, refresh_token, expires_in, :adapter => DiasporaClient.which_faraday_adapter?)
    end
    
    # @return [Integer] Unix time until token experation.
    def expires_in
      (expires_at - Time.now).to_i
    end
  end
end
