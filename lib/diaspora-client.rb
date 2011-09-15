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


  # Sets setter field(s) for the module.
  #
  # @param [Symbol, String] fields Variables to be set
  # @return [void]
  def self.setter(*fields)
    fields.each do |f|
      eval("def self.#{f}=(val) ; @#{f} = val ; end")
    end
  end

  # Sets getter field(s) for the module.
  #
  # @param [Symbol, String] fields Variable to be retrieved
  # @return [void]
  def self.getter(*fields)
    fields.each do |f|
      eval("def self.#{f} ; @#{f} ; end")
    end
  end

  # Creates a getter and setter for every passed in field
  # @see [DiasporaClient#getter]
  # @see [DiasporaClient#setter]
  # @return [void]
  def self.get_and_set(*fields)
    self.getter *fields
    self.setter *fields
  end


  self.get_and_set :private_key_path,
                   :public_key_path,
                   :permissions,
                   :account_class,
                   :account_creation_method

  self.setter :test_mode,
              :application_base_url

  self.getter :manifest_fields


  # Calls {.initialize_instance_variables} and yields to a given (optional) config block.
  #
  # @example
  #   DiasporaClient.config do |d|
  #     d.test_mode = true
  #
  #     #The base url of your application.  Your manifest must be at https://[application/base/url/]manifest.json.
  #     d.application_base_url = "chubbi.es/"
  #
  #     d.manifest_field(:name, "Chubbies")
  #     d.manifest_field(:description, "The best way to chub.")
  #     d.manifest_field(:icon_url, "#")
  #
  #     d.manifest_field(:permissions_overview, "Chubbi.es wants to post photos to your stream.")
  #
  #     d.permission(:profile, :read, "Chubbi.es wants to view your profile so that it can show it to other users.")
  #     d.permission(:photos, :write, "Chubbi.es wants to write to your photos to share your findings with your contacts.")
  #   end
  #
  # @return [void]
  def self.config(&block)
    self.initialize_instance_variables

    if block_given?
      block.call(self)
    end

    if @test_mode
      self.set_test_defaults
    end
    
    if defined?(Rails) && Rails.env == "production" && !@test_mode
      unless self.verify_manifest
        $stderr.puts <<-HELP
******** Your Diaspora* Client is not setup in test mode and ***********
******** Your manifest.json does not match your configuration **********

Please do the following:
1. Double check your configuration (ex. config/diaspora_client.rb).
2. Overwrite your manifest file to match. Run this command:

  rake diaspora:package_manifest

3. Restart your application!
******** Have a great day! **********
HELP
        Process.exit(1)
      end
    end
    

  end

  # Application's current protocol (http/https).
  # The test_mode configuration flag will turn SSL off.
  #
  # @return [String] Protocol
  def self.scheme
    @test_mode ? 'http' : 'https'
  end

  # Retreive the application's public key.
  #
  # @return [String] Application's public key
  def self.public_key
    @public_key ||= File.read(@public_key_path)
  end

  # Retreive the application's private key.
  #
  # @return [OpenSSL::PKey::RSA] Application's private key
  def self.private_key
    @private_key ||= OpenSSL::PKey::RSA.new(File.read(@private_key_path))
  end

  # @return [String] A SHA256 signature of the passed in plaintext with the {.private_key}
  def self.sign(plaintext)
    self.private_key.sign(OpenSSL::Digest::SHA256.new, plaintext)
  end

  # Returns either :em_synchrony or :net_http for Faraday according to
  # if the application is running in an EventMachine reactor loop.
  #
  # @return [Symbol] The Faraday adapter.
  def self.which_faraday_adapter?
    if(defined?(EM::Synchrony) && EM.reactor_running?)
      :em_synchrony
    else
      :net_http
    end
  end

  # Configures Faraday for JSON requests.
  #
  # @return [void]
  def self.setup_faraday
    @faraday_initialized ||= Faraday.default_connection = Faraday::Connection.new do |builder|
      builder.use Faraday::Request::JSON
      builder.adapter self.which_faraday_adapter?
    end
  end

  # Normalizes and adds a scheme and port to @application_base_url.
  #
  # @return [Addressable::URI] The url of the server using DiasporaClient.
  def self.application_base_url
    if @application_base_url.match(/^localhost:\d+/)
      @application_base_url = DiasporaClient.scheme + "://" + @application_base_url
    end

    host = Addressable::URI.heuristic_parse(@application_base_url)
    host.scheme = self.scheme
    host.port ||= host.inferred_port
    host.path = '/' if host.path.blank?
    host
  end

  # Initilizes public & private keys, permissions and manifest fields.
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

    @faraday_initialized = nil

    @account_class = nil
    @account_creation_method = :find_or_create_with_diaspora
  end

  # Defines a field to be placed in the application's manifest.
  #
  # @example
  #  manifest_field(:description, "This application is totally bananas.")
  #
  #
  # @param [Symbol] field
  # @param [String] value
  # @return [void]
  def self.manifest_field(field, value)
    @manifest_fields[field] = value
    nil
  end

  # Defines the permissions the applicaiton is attempting to access.
  #
  # @example
  #  permission(:profile, :read, "Chubbi.es wants to view your profile so that it can show it to other users.")
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

  # Generates the manifest content used in {.package_manifest}.
  # @return [Hash]
  def self.generate_manifest
    @manifest_fields.merge(:permissions => @permissions,
                           :application_base_url => self.application_base_url.to_s)
  end
  
  # Verifies that the manifest located in the public directory is valid
  # @return [Boolean]
  def self.verify_manifest
    JSON.parse(self.package_manifest) == JSON.parse(self.read_manifest)
  end
  
  # Generates a manifest of the form {:public_key => key, :jwt => jwt}
  #
  # @return [String] manifest The resulting manifest.json
  def self.package_manifest
    JSON.generate({:public_key => self.public_key,
                   :jwt => JWT.encode(self.generate_manifest, self.private_key, "RS512")})
  end

  # Writes the manifest file to the public directory of the Rails project
  #
  def self.write_manifest
    puts "writing manifest to: " + self.manifest_path
    man_f = File.new(self.manifest_path, "w")
    man_f.write(DiasporaClient.package_manifest)
    man_f.close
  end

  # Sets default config values for testing
  # @return [void]
  def self.set_test_defaults
    @application_base_url ||= "example.com"
  end

  private

  def self.manifest_path
    @manifest_path ||=  File.join(Rails.root, "public", "manifest.json")
  end

  def self.read_manifest
    @read_manifest ||= File.read(File.join(Rails.root, "public", "manifest.json"))
  end

end

