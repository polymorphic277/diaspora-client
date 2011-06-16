module DiasporaClient
  require 'sinatra'
  require 'oauth2'
  require 'active_record'
  require 'em-synchrony' if RUBY_VERSION.include? "1.9"
  autoload :App,            File.join('diaspora-client', 'app')
  autoload :AccessToken,    File.join('diaspora-client', 'access_token')
  autoload :ResourceServer, File.join('diaspora-client', 'resource_server')


  def self.config(&block)
    self.initialize_instance_variables

    if block_given?
      block.call(self)
    end
  end

  def self.scheme
    @test_mode ? 'http' : 'https'
  end

  def self.test_mode=(value)
    @test_mode = value
  end

  def self.application_url=(value)
    @application_url = value
  end
  
  def self.public_key_path
    @public_key_path
  end

  def self.public_key_path= path
    @public_key_path = path
  end

  def self.public_key
    @public_key ||= File.read(@public_key_path)
  end

  def self.private_key_path
    @private_key_path
  end

  def self.private_key_path= path
    @private_key_path = path
  end

  def self.setup_faraday
     Faraday.default_connection = Faraday::Connection.new do |builder|
       builder.use Faraday::Request::JSON
       if(defined?(EM::Synchrony) && EM.reactor_running?)
         builder.use Faraday::Adapter::EMSynchrony  
       else
         builder.adapter :net_http
       end
     end
  end

  def self.application_host
    host = Addressable::URI.heuristic_parse(@application_url)
    host.scheme = self.scheme
    host.port ||= host.inferred_port
    host
  end

  def self.private_key
    @private_key ||= OpenSSL::PKey::RSA.new(File.read(@private_key_path))
  end

  def self.initialize_instance_variables
    @private_key_path = "/config/private.pem" 
    @private_key = nil

    @public_key_path = "/config/public.pem" 
    @public_key = nil
    @test_mode = false
    @application_url = 'example.com'
    self.setup_faraday
  end
end

