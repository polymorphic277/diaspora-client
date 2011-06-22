module DiasporaClient
  class App < Sinatra::Base
    def client
      pod.client
    end

    def pod
      @pod ||= lambda{
        host = diaspora_handle.split('@')[1]
        ResourceServer.where(:host => host).first || ResourceServer.register(host)
      }.call
    end

    def diaspora_handle
      params['diaspora_handle']
    end

    def redirect_path
      '/auth/diaspora/callback'
    end

    def after_oauth_redirect_path
      '/users/edit'
    end

    def redirect_uri
      uri = Addressable::URI.parse(request.url)
      uri.path = redirect_path
      uri.query_values = {:diaspora_handle => diaspora_handle}
      uri.to_s
    end

    def current_user
      request.env["warden"].user
    end

    get '/' do
     begin
        redirect client.web_server.authorize_url(
          :redirect_uri => redirect_uri,
          :scope => 'profile,AS_photo:post'
        )
     rescue Exception => e
       redirect (back.to_s + "?diaspora-client-error=#{URI.escape(e.message)}")
     end
    end

    get '/callback' do
      unless params["error"]
        access_token = client.web_server.get_access_token(params[:code], :redirect_uri => redirect_uri)
        user = JSON.parse(access_token.get('/api/v0/me'))

        current_user.create_access_token(
          :uid => user["uid"],
          :resource_server_id => pod.id,
          :access_token => access_token.token,
          :refresh_token => access_token.refresh_token,
          :expires_at => access_token.expires_at
        )
      end

      redirect after_oauth_redirect_path
    end

    delete '/' do
      current_user.access_token.destroy
      redirect after_oauth_redirect_path
    end

  end
end
