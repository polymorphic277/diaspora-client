module DiasporaClient
  require 'jwt'
  require 'sinatra'
  require 'oauth2'
  require 'active_record'
  require 'em-synchrony' if RUBY_VERSION.include? "1.9"
  require 'diaspora-client/railtie' if defined?(Rails)

  autoload :App,            File.join('diaspora-client', 'app')
  autoload :AccessToken,    File.join('diaspora-client', 'access_token')
  autoload :ResourceServer, File.join('diaspora-client', 'resource_server')


  PROFILE = "profile"
  PHOTOS = "photos"
  READ = "read"
  WRITE = "write"


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

  #getter
  [:manifest_fields].each do |field|

    eval(self.getter_string(field))
  end

  #getters and setters
  [:private_key_path,
   :public_key_path,
   :permissions].each do |field|

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

  # Configures Faraday for JSON requests
  #
  # @return [void]
  def self.setup_faraday
    Faraday.default_connection = Faraday::Connection.new do |builder|
      builder.use Faraday::Request::JSON
      builder.adapter self.which_faraday_adapter? 
    end
  end

  # Parses host and port from @application_url
  # 
  # @return [String] Host of application
  def self.application_host
    host = Addressable::URI.heuristic_parse(@application_url)
    host.scheme = self.scheme
    host.port ||= host.inferred_port
    host
  end

  # Initilizes public & private keys, permissions and manifest fields.
  # This method also runs setup_faraday.
  #
  # @return [void]
  def self.initialize_instance_variables
    app_name = (defined?(Rails)) ? "#{Rails.application.class.parent_name}." : ""
    app_root = (defined?(Rails)) ? "#{Rails.root}" : ""

    @permissions = {}
    @manifest_fields = {}

    @private_key_path = "#{app_root}/config/#{app_name}private.pem"
    @private_key = nil

    @public_key_path = "#{app_root}/config/#{app_name}public.pem"
    @public_key = nil

    @test_mode = false
    @application_url = 'example.com'
    self.setup_faraday
  end

  # Defines a field to be placed in the application's manifest
  #
  # @param [Symbol] field
  # @param [String] value
  # @return [void]
  def self.manifest_field(field, value)
    @manifest_fields[field] = value
    nil
  end

  # Defines the permissions the applicaiton is attempting to access
  #
  # @param [Symbol] type The type of content to be accessed
  # @param [Symbol] access Read/write access of the specified type
  # @param [String] description Human readable description of what the permission will be used for
  # @return [void]
  def self.permission(type, access, description)
    @permissions[type] = {:type => "DiasporaClient::#{type.to_s.upcase}".constantize,
                          :access => "DiasporaClient::#{access.to_s.upcase}".constantize,
                          :description => description}
  end

  # Generates a manifest of the form {:public_key => key, :jwt => jwt}
  #
  # @return [String] manifest The resulting manifest.json
  def self.package_manifest
    manifest = @manifest_fields.merge(:permissions => @permissions)

    JSON.generate({:public_key => self.public_key,
                   :jwt => JWT.encode(manifest, self.private_key, "RS512")})
  end
end

