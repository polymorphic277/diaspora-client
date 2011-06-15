module DiasporaClient
  class ResourceServer < ActiveRecord::Base
    attr_accessible :host, :client_id, :client_secret

    def self.register(host, self_url)
      self_url = "#{self_url.host}:#{self_url.port}" if self_url.respond_to?(:host)
      pod = self.new(:host => host)

# TODO
#     connection = Faraday::Connection.new do |builder|
#       builder.use Faraday::Adapter::EMSynchrony  if(defined?(EM::Synchrony) && EM.reactor_running?)
#     end
      if defined?(EM::Synchrony) && EM.reactor_running?
        connection = Faraday::Connection.new do |builder|
            builder.use Faraday::Adapter::EMSynchrony
        end
      else
        connection = Faraday.default_connection
      end


      response = connection.post("http://#{host}/oauth/token", pod.build_register_body(self_url))

      json = JSON.parse(response.body)
      pod.update_attributes(json)
      pod.save!
      pod
    end

    def signable_string(self_url)
      [ "http://#{self_url}/",
        "http://#{self.host}/",
        Time.now.to_i,
        ActiveSupport::SecureRandom.base64(32)
      ].join(';')
    end

    def build_register_body(self_url)
      signable_str = self.signable_string(self_url)
      {
        :type => :client_associate,
        :manifest_url =>"http://#{self_url}/manifest.json",
        :signed_string => Base64.encode64(signable_str),
        :signature => Base64.encode64(signature(signable_str))
      }
    end


   def signature(plaintext)
     DiasporaClient.private_key.sign( OpenSSL::Digest::SHA256.new, plaintext)
   end

    def client
      @client ||= OAuth2::Client.new(client_id, client_secret, :site => "http://#{host}/api/v0")
    end
  end
end
