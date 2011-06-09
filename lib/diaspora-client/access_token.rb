module DiasporaClient
  class AccessToken < ActiveRecord::Base
    belongs_to :user
    belongs_to :resource_server

    def token
      @token ||= OAuth2::AccessToken.new( resource_server.client, access_token, refresh_token, expires_in)
    end

    def expires_in
      (expires_at - Time.now).to_i
    end
  end
end
