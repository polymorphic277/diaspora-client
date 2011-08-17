require 'addressable/uri'

module DiasporaClient
  class App < Sinatra::Base

    # @return [OAuth2::Client] The connecting Diaspora installation's Client object.
    # @see #pod
    def client
      pod.client
    end

    # Find a pre-existing Diaspora server, or register with a new one.
    #
    # @note The Diaspora server is parsed from the domain in the given diaspora handle.
    # @return [ResourceServer]
    def pod
      @pod ||= lambda{
        host = diaspora_id.split('@')[1]
        ResourceServer.where(:host => host).first || ResourceServer.register(host)
      }.call
    end

    # Retreive the user's Diaspora id from the params hash.
    #
    # @return [String]
    def diaspora_id
      @diaspora_id ||= params['diaspora_id'].strip
    end

    def uid
      @uid ||= diaspora_id.split('@')[0]
    end

    # @return [String] The path to hit after retreiving an access token from a Diaspora server.
    def redirect_path
      '/auth/diaspora/callback'
    end

    # @return [String] The path to send the user after the OAuth2 dance is complete.
    def after_oauth_redirect_path
      '/'
    end

    # @option hash [String] :diaspora_id The connecting user's diaspora id
    # @return [ActiveRecord::Base] A created and persisted user account which an access token can be attached to.
    def create_account(hash)
      DiasporaClient.account_class.send(DiasporaClient.account_creation_method, hash)
    end

    # @return [String] The URL to hit after retreiving an access token from a Diaspora server.
    # @see #redirect_path
    def redirect_uri
      uri = Addressable::URI.parse(request.url)
      uri.path = redirect_path
      uri.query_values = {:diaspora_id => diaspora_id}
      uri.to_s
    end

    # @return [User] The current user stored in warden.
    def current_user
      request.env["warden"].user
    end

    def current_user=(user)
      request.env["warden"].set_user(user, :scope => :user, :store => true)
    end

    # @return [void]
    get '/' do

      # ensure faraday is configured
      DiasporaClient.setup_faraday

      begin
        redirect client.web_server.authorize_url(
          :redirect_uri => redirect_uri,
          :scope => 'profile,AS_photo:post',
          :uid => uid
        )
      rescue Exception => e
        redirect_url = back.to_s
        if defined?(Rails)
          flash_class = ActionDispatch::Flash
          flash = request.env["action_dispatch.request.flash_hash"] ||= flash_class::FlashHash.new
          flash.alert = e.message
        else
          redirect_url << "?diaspora-client-error=#{URI.escape(e.message[0..800])}"
        end
        redirect redirect_url
      end
    end

    # @return [void]
    get '/callback' do
      if !params["error"]

        access_token = client.web_server.get_access_token(params[:code], :redirect_uri => redirect_uri)

        user_json = JSON.parse(access_token.get('/api/v0/me'))

        url = Addressable::URI.parse(client.web_server.authorize_url).normalized_host
        if port = Addressable::URI.parse(client.web_server.authorize_url).normalized_port
          url += ":#{port}"
        end

        self.current_user ||= create_account(:diaspora_id => user_json['uid'] + "@" + url)

        if at = current_user.access_token
          at.destroy
          current_user.access_token = nil
        end

        current_user.create_access_token(
          :uid => user_json["uid"],
          :resource_server_id => pod.id,
          :access_token => access_token.token,
          :refresh_token => access_token.refresh_token,
          :expires_at => access_token.expires_at
        )

      elsif params["error"] == "invalid_client"
        ResourceServer.register(diaspora_id.split('@')[1])
        redirect "/?diaspora_id=#{diaspora_id}"
      end

      redirect after_oauth_redirect_path
    end

    # Destroy the current user's access token and redirect.
    #
    # @return [void]
    delete '/' do
      current_user.access_token.destroy
      redirect after_oauth_redirect_path
    end

  end
end
