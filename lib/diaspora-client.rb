module DiasporaClient
  require 'sinatra'
  require 'oauth2'
  require 'active_record'
  require 'em-synchrony' if RUBY_VERSION.include? "1.9"
  require 'diaspora-client/railtie' if defined?(Rails)

  autoload :App,            File.join('diaspora-client', 'app')
  autoload :AccessToken,    File.join('diaspora-client', 'access_token')
  autoload :ResourceServer, File.join('diaspora-client', 'resource_server')


  def self.setter_string(field)
    "def self.#{field}=(val) ; @#{field} = val ; end"
  end

  def self.getter_string(field)
    "def self.#{field} ; @#{field} ; end"
  end

  #setters
  [:test_mode,
   :application_url].each do |field|

      eval(self.setter_string(field))
  end

  #getters and setters
  [:app_name,
   :description,
   :homepage_url,
   :icon_url,
   :permissions_overview,
   :private_key_path,
   :public_key_path].each do |field|

      eval(self.getter_string(field))
      eval(self.setter_string(field))
  end

  def self.config(&block)
    self.initialize_instance_variables

    if block_given?
      block.call(self)
    end
  end

  def self.scheme
    @test_mode ? 'http' : 'https'
  end

  def self.public_key
    @public_key ||= File.read(@public_key_path)
  end

  def self.private_key
    @private_key ||= OpenSSL::PKey::RSA.new(File.read(@private_key_path))
  end

  def self.which_faraday_adapter?
    if(defined?(EM::Synchrony) && EM.reactor_running?)
      :em_synchrony  
    else
      :net_http
    end
  end

  def self.setup_faraday
     Faraday.default_connection = Faraday::Connection.new do |builder|
       builder.use Faraday::Request::JSON
       builder.adapter self.which_faraday_adapter? 
     end
  end

  def self.application_host
    host = Addressable::URI.heuristic_parse(@application_url)
    host.scheme = self.scheme
    host.port ||= host.inferred_port
    host
  end

  def self.initialize_instance_variables
    app_name = (defined?(Rails)) ? "#{Rails.application.class.parent_name}." : ""

    @private_key_path = "/config/#{app_name}private.pem"
    @private_key = nil

    @public_key_path = "/config/#{app_name}public.pem"
    @public_key = nil

    @test_mode = false
    @application_url = 'example.com'
    self.setup_faraday
  end
end

