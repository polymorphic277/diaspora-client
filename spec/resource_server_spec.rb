require 'helper'
describe DiasporaClient::ResourceServer do
  include DiasporaClient
  before do
    @host = "diasporap.od"
    @self_url = "chubbi.es"
    @time = Time.now
    Time.stub(:now).and_return(@time)

    DiasporaClient.private_key_path = File.dirname(__FILE__) + "/chubbies.private.pem"
  end

  describe '.register' do
    it 'posts to the token endpoint' do
      response = mock()
      resp_str = {:client_id => "aofosdjfg", :client_secret => "aosfjosdigh"}.to_json.to_s
      response.stub!(:body).and_return(resp_str)
      response.stub!(:success?).and_return(true)

      body = {:a => 'b'}
      ResourceServer.any_instance.should_receive(:build_register_body).and_return(body)

      conn = mock()
      conn.should_receive(:post).
        with("https://#{@host}:443/oauth/token", body).
        and_return(response)
      Faraday.stub(:default_connection).and_return(conn)

      ResourceServer.register(@host)
    end

    it 'raises if the connection response is not acceptable' do
       conn = mock
       conn.stub_chain(:post, :success? => false)
       Faraday.stub(:default_connection).and_return(conn)


      lambda{
        ResourceServer.register(@host)
      }.should raise_error /Failed to connect to Diaspora server./
    end
  end

  context 'uris' do
      before do
        @res = ResourceServer.new(:host => 'pod.pod')
      end
    describe '#full_host' do
      it 'returns the https url by default' do
        @res.full_host.scheme.should == "https"
      end
      
      it 'returns the http scheme if test mode is configured' do
        DiasporaClient.config do |d|
          d.test_mode = true
        end
        @res.full_host.scheme.should == "http"
      end

      it 'includes the pod uri' do
        @res.full_host.host.should == "pod.pod"
      end
    end

    describe '#token_endpoint' do
      it 'retruns the default route' do
        @res.token_endpoint.should include(@res.full_host + "/oauth/token")
      end
    end

    describe '#api_route' do
      it 'retruns the default route' do
        @res.api_route.should include(@res.full_host + "/api/v0")
      end
    end
  end

  describe '#build_register_body' do
    before do
      @resource = ResourceServer.new(:host => @host)
    end
    it 'sets the type' do
      @resource.build_register_body[:type].should == :client_associate
    end

    it 'sets the https app url by default' do
       @resource.build_register_body[:app_url].should == "https://example.com:443"
    end

    it 'sets the http app url in test mode' do
       @resource.stub(:signature).and_return("YAY!!")
        DiasporaClient.config do |d|
          d.test_mode = true
          d.application_url = "url.com"
        end
       @resource.build_register_body[:app_url].should == "http://url.com:80"
    end

    it 'returns base64 encoded signable string' do
      str = "asdfas"
      @resource.stub(:signable_string).and_return(str)
      @resource.build_register_body[:signed_string].should == Base64.encode64(str)
    end

    it 'returns base64 encoded signature' do
      str = "SIG"
      @resource.stub(:signature).and_return(str)
      @resource.build_register_body[:signature].should == Base64.encode64(str)
    end
  end

  describe '#signature' do
    it 'signs the plaintext' do
      plaintext = "cats"
      DiasporaClient.private_key.should_receive(:sign).with( OpenSSL::Digest::SHA256.new, plaintext).and_return("sig")

      ResourceServer.new(:host => @host).signature(plaintext).should == "sig"
    end
  end

  describe '#signable_string' do
    it 'returns a signable string' do
      pod = ResourceServer.new(:host => @host)
      ActiveSupport::SecureRandom.stub!(:base64).and_return("nonce")
      signable_string = ["https://example.com:443", "https://#{@host}:443", @time.to_i, "nonce"].join(';')
      pod.signable_string.should == signable_string
    end
  end
end
