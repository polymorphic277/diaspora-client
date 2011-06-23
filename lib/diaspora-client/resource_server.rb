require 'addressable/uri'
require 'addressable/template'

module DiasporaClient
  class ResourceServer < ActiveRecord::Base
    attr_accessible :host, :client_id, :client_secret

    def self.register(host)
      pod = self.new(:host => host)
      response = Faraday.post(pod.token_endpoint, pod.build_register_body)
     
      unless response.success?
        raise "failed to connect to diaspora server"
      end

      json = JSON.parse(response.body)
      pod.update_attributes(json)
      pod.save!
      pod
    end
    
    #client methods
    def client
      @client ||= OAuth2::Client.new(client_id, client_secret, :site => self.api_route)
    end


    def build_register_body
      signable_str = self.signable_string
      {
        :type => :client_associate,
        :manifest_url => self.manifest_url,
        :signed_string => Base64.encode64(signable_str),
        :signature => Base64.encode64(signature(signable_str))
      }
    end

    #url helper methods
    def manifest_url
      url = DiasporaClient.application_host
      url.path = '/manifest.json'
      url.to_s
    end

    def full_host
      a = Addressable::URI.heuristic_parse(DiasporaClient.scheme + "://" + self.host)
      a.port ||= a.inferred_port
      a
    end

    def token_endpoint
      url = self.full_host
      url.path = '/oauth/token' 
      url.to_s
    end

    def api_route
      url = self.full_host
      url.path = '/api/v0' 
      url.to_s
    end

    #encryption methods
   def signature(plaintext)
     DiasporaClient.private_key.sign( OpenSSL::Digest::SHA256.new, plaintext)
   end

    def signable_string
      [ DiasporaClient.application_host,
        self.full_host,
        Time.now.to_i,
        ActiveSupport::SecureRandom.base64(32)
      ].join(';')
    end
  end
end
