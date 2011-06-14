module DiasporaClient
  require 'sinatra'
  require 'oauth2'
  require 'active_record'
  require 'em-synchrony' if RUBY_VERSION.include? "1.9"
  autoload :App,            File.join('diaspora-client', 'app')
  autoload :AccessToken,    File.join('diaspora-client', 'access_token')
  autoload :ResourceServer, File.join('diaspora-client', 'resource_server')


  def self.private_key_path
    @private_key_path
  end

  def self.private_key_path= path
    @private_key_path = path
  end

  def self.initialize_instance_variables
    @private_key_path = nil
    if defined?(Rails) && !Rails.root.nil?
      @private_key_path = Rails.root + "/config/private.pem" 
    end

    @private_key = nil
  end

  def self.private_key
    @private_key ||= OpenSSL::PKey::RSA.new(File.read(@private_key_path))
  end
  self.initialize_instance_variables
end

