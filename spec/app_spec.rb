require 'helper'

describe DiasporaClient::App do
  include Rack::Test::Methods
  def app
    @app ||= DiasporaClient::App
  end

  it "should respond to /" do
    get '/'
    last_response.should be_redirect
  end

  it 'redirects back with an error if post fails or params are incorrect' do
    get '/'
    last_response.headers['Location'].include?("diaspora-client-error").should be_true
  end

end
