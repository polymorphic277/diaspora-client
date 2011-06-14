module DiasporaClient
  class ResourceServer < ActiveRecord::Base
    attr_accessible :host, :client_id, :client_secret

    def self.register(host, self_url)
      self_url = "#{self_url.host}:#{self_url.port}" if self_url.respond_to?(:host)
      pod = self.new(:host => host)

      if defined?(EM::Synchrony) && EM.reactor_running?
        connection = Faraday::Connection.new do |builder|
            builder.use Faraday::Adapter::EMSynchrony
        end
      else
        connection = Faraday.default_connection
      end

      response = connection.post("http://#{host}/oauth/token",
                                  {:type => :client_associate,
                                   :manifest_url =>"http://#{self_url}/manifest.json"})

      json = JSON.parse(response.body)
      pod.update_attributes(json)
      pod.save!
      pod
    end

    def client
      @client ||= OAuth2::Client.new(client_id, client_secret, :site => "http://#{host}/api/v0")
    end
  end
end
