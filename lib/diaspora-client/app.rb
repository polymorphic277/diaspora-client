module DiasporaClient
  class App < Sinatra::Base
    def client
      pod.client
    end

    def pod
      @pod ||= lambda{
        host = diaspora_handle.split('@')[1]
        ResourceServer.where(:host => host).first || ResourceServer.register(host, URI.parse(request.url))
      }.call
    end

    def diaspora_handle
      params['diaspora_handle']
    end

    def redirect_uri
      uri = URI.parse(request.url)
      uri.path = '/auth/diaspora/callback'
      uri.query = {:diaspora_handle => diaspora_handle }.to_query
      uri.to_s
    end

    get '/' do
      redirect client.web_server.authorize_url(
        :redirect_uri => redirect_uri,
        :scope => 'profile,AS_photo:post'
      )
    end

    get '/callback' do
      unless params["error"]
        access_token = client.web_server.get_access_token(params[:code], :redirect_uri => redirect_uri)
        user = JSON.parse(access_token.get('/api/v0/me'))

        request.env["warden"].user.create_access_token(
          :uid => user["uid"],
          :resource_server_id => pod.id,
          :access_token => access_token.token,
          :refresh_token => access_token.refresh_token,
          :expires_at => access_token.expires_at
        )
      end

      redirect "/users/edit"
    end

    delete '/' do
      request.env["warden"].user.access_token.destroy
      redirect "/users/edit"
    end

  end
end
