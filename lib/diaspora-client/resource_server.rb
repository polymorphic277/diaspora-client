require 'addressable/uri'
require 'addressable/template'

module DiasporaClient
  class RegistrationError < RuntimeError; end
  class ResourceServer < ActiveRecord::Base
    attr_accessible :host, :client_id, :client_secret

    # Register this application at the pod located at host
    # @param [String] host The location of a Diaspora server.
    # @raise [RegistrationError] If the Diaspora server returns a non-20x response code.
    # @return [ResourceServer] The new model of the server located at host.
    def self.register(host)
      pod = self.find_or_initialize_by_host(host)
      response = Faraday.post(pod.token_endpoint, pod.build_register_body)

      unless(response.present? && response.success?)
        message = "Failed to connect to Diaspora server: "
        message += response.body if response.body
        raise RegistrationError.new(message)
      end

      json = JSON.parse(response.body)
      pod.update_attributes(json)
      pod.save!
      pod
    end

    # @return [OAuth2::Client]
    def client
      @client ||= OAuth2::Client.new(client_id, client_secret, :site => api_route)
    end

    # Constructs the body of the request during registration.
    #
    # @return [Hash] Parameters of the pre-registration request
    def build_register_body
      signable_str = self.signable_string
      {
        :type => :client_associate,
        :signed_string => Base64.encode64(signable_str),
        :signature => Base64.encode64(DiasporaClient.sign(signable_str))
      }
    end

    # @return [String] a semicolon separated string of the fields that need to be signed for
    #                  the registration request.
    def signable_string
      [ DiasporaClient.application_base_url,
        full_host,
        Time.now.to_i,
        ActiveSupport::SecureRandom.base64(32)
      ].join(';')
    end

    #TODO(*) these methods should be private -----------------------------------

    # @return [Addressable::URI] The URI of the Diaspora pod represented by this record.
    def full_host
      a = Addressable::URI.heuristic_parse(DiasporaClient.scheme + "://" + self.host)
      a.port ||= a.inferred_port
      a
    end

    # @return [String] The registration endpoint of this Diaspora pod.
    def token_endpoint
      url = self.full_host
      url.path = '/oauth/token'
      url.to_s
    end

    # @return [String] Root API route of this Diaspora pod.
    def api_route
      url = self.full_host
      url.path = '/api/v0'
      url.to_s
    end

  end
end
