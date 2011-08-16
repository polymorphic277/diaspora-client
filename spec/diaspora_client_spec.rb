require 'helper'
describe DiasporaClient do

  context 'application private key' do

    before do
      pub_key_path = File.dirname(__FILE__) + "/chubbies.public.pem"
      private_key_path = File.dirname(__FILE__) + "/chubbies.private.pem"

      DiasporaClient.config do |p|
        p.public_key_path = pub_key_path
        p.private_key_path = private_key_path
      end

      @priv_key_fixture = File.read(private_key_path)
      @public_key_fixture = File.read(pub_key_path)
    end

    it 'returns an OpenSSL key' do
      DiasporaClient.private_key.class.should == OpenSSL::PKey::RSA
    end

    it 'reads and returns the private key' do
      DiasporaClient.private_key.to_s.should == @priv_key_fixture
    end

    it 'reads and returns the public key' do
      DiasporaClient.public_key.to_s.should == @public_key_fixture
    end

    it 'allows for custom path' do
      path = "/path/to/key.pem"
      DiasporaClient.private_key_path = path
      File.should_receive(:read).with(path).and_return(@priv_key_fixture)
      DiasporaClient.private_key
    end

    it 'memoizes the private key reading' do
      File.should_receive(:read).with(DiasporaClient.private_key_path).once.and_return(@priv_key_fixture)
      DiasporaClient.private_key
      DiasporaClient.private_key
    end

    describe '.sign' do
      it 'signs plaintext' do
        plaintext = "cats"
        DiasporaClient.private_key.should_receive(:sign).with( OpenSSL::Digest::SHA256.new, plaintext)
        DiasporaClient.sign(plaintext)
      end
    end
  end

  describe ".config" do
    it 'runs the block passed to it' do
      DiasporaClient.config do |d|
        d.private_key_path = "AWESOME"
        d.public_key_path = "SAUCE"
      end

      DiasporaClient.private_key_path.should == "AWESOME"
      DiasporaClient.public_key_path.should == "SAUCE"
    end

    it 'sets smart defaults' do
      DiasporaClient.should_receive(:initialize_instance_variables)
      DiasporaClient.config do |d|
      end
    end

    it 'sets the manifest fields' do
      DiasporaClient.config do |d|
        d.manifest_field(:name, "Chubbies")
        d.manifest_field(:description, "The best way to chub.")
        d.manifest_field(:icon_url, "#")

        d.manifest_field(:permissions_overview, "Chubbi.es wants to post photos to your stream.")
      end

      DiasporaClient.manifest_fields[:name].should == "Chubbies"
      DiasporaClient.manifest_fields[:description].should == "The best way to chub."
      DiasporaClient.manifest_fields[:icon_url].should == "#"
      DiasporaClient.manifest_fields[:permissions_overview].should == "Chubbi.es wants to post photos to your stream."
    end


    it 'sets the permission requests and descriptions' do
      DiasporaClient.config do |d|
       d.permission(:profile, :read, "Chubbi.es wants to view your profile so that it can show it to other users.")
       d.permission(:photos, :write, "Chubbi.es wants to write to your photos to share your findings with your contacts.")
      end

      pr = DiasporaClient.permissions[:profile]
      pr[:access].should == DiasporaClient::READ
      pr[:type].should == DiasporaClient::PROFILE
      pr[:description].should == "Chubbi.es wants to view your profile so that it can show it to other users."

      pr = DiasporaClient.permissions[:photos]
      pr[:access].should == DiasporaClient::WRITE
      pr[:type].should == DiasporaClient::PHOTOS
      pr[:description].should == "Chubbi.es wants to write to your photos to share your findings with your contacts."
    end

    it 'sets account_class and account_creation_method' do
      DiasporaClient.account_class.should == nil
      DiasporaClient.account_creation_method.should == :create_with_diaspora

      DiasporaClient.config do |d|
        d.account_class = URI
        d.account_creation_method = :parse
      end

      DiasporaClient.account_class.should == URI
      DiasporaClient.account_creation_method.should == :parse
    end
  end

  describe 'setup_faraday' do
    it 'uses net:http if not in a reactor and 1.9.2' do
      DiasporaClient.setup_faraday

      conn = Faraday.default_connection
      conn.builder.handlers.should_not include(Faraday::Adapter::EMSynchrony)
    end

    it 'uses JSON encode request' do
      DiasporaClient.setup_faraday

      conn = Faraday.default_connection
      conn.builder.handlers.should include(Faraday::Request::JSON)
    end

    it 'uses net:http if not in a reactor and 1.9.2' do
      EM.stub(:reactor_running?).and_return(true)
      DiasporaClient.setup_faraday

      conn = Faraday.default_connection
      conn.builder.handlers.should include(Faraday::Adapter::EMSynchrony)
    end
  end

  describe '.application_base_url' do
    it 'works with localhost' do
      DiasporaClient.config do |d|
        d.application_base_url = "localhost:6924"
      end
      DiasporaClient.application_base_url.to_s.should == "https://localhost:6924/"
    end

    it 'normalizes application_base_url' do
      DiasporaClient.config do |d|
        d.application_base_url= "google.com"
      end

      DiasporaClient.application_base_url.to_s.should == "https://google.com:443/"
    end
  end

  describe ".scheme" do
    it 'sets the https app url by default' do
      DiasporaClient.scheme.should == 'https'
    end

    it 'sets the http app url in test mode' do
      DiasporaClient.config do |d|
        d.test_mode = true
      end
      DiasporaClient.scheme.should == 'http'
    end
  end

  context "manifest" do
    before do
      pub_key_path = File.dirname(__FILE__) + "/chubbies.public.pem"
      private_key_path = File.dirname(__FILE__) + "/chubbies.private.pem"

      DiasporaClient.config do |d|
        d.public_key_path = pub_key_path
        d.private_key_path = private_key_path
        d.application_base_url = "http://localhost:4000/"

        d.manifest_field(:name, "Chubbies")
        d.manifest_field(:description, "The best way to chub.")
        d.manifest_field(:icon_url, "#")

        d.manifest_field(:permissions_overview, "Chubbi.es wants to post photos to your stream.")

        d.permission(:profile, :read, "Chubbi.es wants to view your profile so that it can show it to other users.")
        d.permission(:photos, :write, "Chubbi.es wants to write to your photos to share your findings with your contacts.")
      end
    end

    describe ".generate_manifest" do
      it 'puts application_base_url into the manifest' do
        DiasporaClient.generate_manifest[:application_base_url].should_not be_blank
      end
    end


    describe ".package_manifest" do
      it 'puts the public key in the manifest package' do
        JSON.parse(DiasporaClient.package_manifest)['public_key'].should_not be_blank
      end

      context "JWT" do
        before do
          @packaged_manifest_jwt = JSON.parse(DiasporaClient.package_manifest)['jwt']
          @pub_key = OpenSSL::PKey::RSA.new(DiasporaClient.public_key)
        end

        it 'is present' do
          @packaged_manifest_jwt.should_not be_blank
        end

        it 'has all manifest fields' do
          JWT.decode(@packaged_manifest_jwt, @pub_key).symbolize_keys.should include(DiasporaClient.manifest_fields)
        end

        it 'has all permission fields' do
          jwt_permissions = JWT.decode(@packaged_manifest_jwt, @pub_key)["permissions"].symbolize_keys
          jwt_permissions.keys.each do |key|
            jwt_permissions[key].symbolize_keys.should == DiasporaClient.permissions[key]
          end
        end
      end
    end
  end
end
