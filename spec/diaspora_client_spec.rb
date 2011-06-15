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
  end
end
