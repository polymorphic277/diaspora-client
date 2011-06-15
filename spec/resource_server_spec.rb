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
    it 'posts' do
      response = mock()
      resp_str = {:client_id => "aofosdjfg", :client_secret => "aosfjosdigh"}.to_json.to_s
      response.stub!(:body).and_return(resp_str)

      body = {:a => 'b'}
      ResourceServer.any_instance.should_receive(:build_register_body).and_return(body)

      conn = mock()
      conn.should_receive(:post).
        with("http://#{@host}/oauth/token", body).
        and_return(response)
      Faraday::Connection.stub(:new).and_return(conn)

      ResourceServer.register(@host, @self_url)
    end
  end

  describe '#build_register_body' do
    before do
      @resource = ResourceServer.new(:host => @host)
    end
    it 'sets the type' do
      @resource.build_register_body('')[:type].should == :client_associate
    end

    it 'sets the manifest url' do
       @resource.build_register_body("url.com")[:manifest_url].should == "http://url.com/manifest.json"
    end
    
    it 'return encoded signable string' do
      str = "asdfas"
      @resource.stub(:signable_string).and_return(str)
      @resource.build_register_body('')[:signed_string].should == Base64.encode64(str)
    end

    it 'return encoded signature' do
      str = "SIG"
      @resource.stub(:signature).and_return(str)
      @resource.build_register_body('')[:signature].should == Base64.encode64(str)
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
      signable_string = ["http://#{@self_url}/", "http://#{@host}/", @time.to_i, "nonce"].join(';')
      pod.signable_string(@self_url).should == signable_string
    end
  end
end
